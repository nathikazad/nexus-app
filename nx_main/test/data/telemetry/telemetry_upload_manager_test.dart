import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nexus_voice_assistant/data/telemetry/telemetry_upload_manager.dart';
import 'package:nx_db/auth.dart';

Uint8List _packet(int transferId, String content) {
  final name = utf8.encode('telemetry.jsonl');
  final payload = utf8.encode(content);
  final bytes = Uint8List(19 + name.length + payload.length);
  final data = ByteData.sublistView(bytes);
  bytes[0] = 0x00;
  bytes[1] = 0x02;
  bytes[2] = 0x01;
  data.setUint32(3, transferId, Endian.little);
  data.setUint16(7, 0, Endian.little);
  bytes[9] = 0x02;
  data.setUint32(10, payload.length, Endian.little);
  data.setUint32(14, 0, Endian.little);
  bytes[18] = name.length;
  bytes.setRange(19, 19 + name.length, name);
  bytes.setRange(19 + name.length, bytes.length, payload);
  return bytes;
}

void main() {
  test('telemetry refreshes once and a switched account uses its own token',
      () async {
    final seen = <String>[];
    var firstRequests = 0;
    final first = NexusAuthenticatedClient(
      preset: BackendPreset.piWan,
      userId: '7',
      inner: MockClient((request) async {
        firstRequests++;
        seen.add(request.headers['authorization']!);
        return http.Response(
          firstRequests == 1 ? 'expired' : '{"ok":true}',
          firstRequests == 1 ? 401 : 200,
        );
      }),
      authHeaders: (refresh) async => {
        'authorization': 'Bearer ${refresh ? 'account-a-new' : 'account-a'}',
      },
    );
    final second = NexusAuthenticatedClient(
      preset: BackendPreset.piWan,
      userId: '8',
      inner: MockClient((request) async {
        seen.add(request.headers['authorization']!);
        return http.Response('{"ok":true}', 200);
      }),
      authHeaders: (_) async => {'authorization': 'Bearer account-b'},
    );
    final committed = <int>[];

    await TelemetryUploadManager(
      httpBaseUrl: 'https://example.test',
      client: first,
      onCommitted: (id) async => committed.add(id),
    ).handlePacket(_packet(1, '{"sample":1}\n'));
    await TelemetryUploadManager(
      httpBaseUrl: 'https://example.test',
      client: second,
      onCommitted: (id) async => committed.add(id),
    ).handlePacket(_packet(2, '{"sample":2}\n'));

    expect(seen, [
      'Bearer account-a',
      'Bearer account-a-new',
      'Bearer account-b',
    ]);
    expect(committed, [1, 2]);
    first.close();
    second.close();
  });
}
