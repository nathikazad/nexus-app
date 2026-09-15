import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nx_auth/nx_auth.dart';
import 'package:nx_hypnosis/remote_collection.dart';

void main() {
  final user = User(userId: '1', preset: BackendPreset.hosted);
  Map<String, dynamic> payload() => {
    'person_id': 1,
    'desires': [
      {'id': '10', 'title': 'Faith', 'belief': 'Trust'},
    ],
    'tapes': [
      {
        'id': '20',
        'title': 'Morning',
        'desire_id': '10',
        'story': 'Rest.',
        'audio': {'link': '/hypnosis/recordings/20'},
      },
    ],
  };
  test(
    'Loads server IDs and downloads audio through authenticated transport',
    () async {
      final paths = <String>[];
      final client = NexusAuthenticatedClient(
        preset: user.preset,
        userId: user.userId,
        authHeaders: (_) async => {'authorization': 'Bearer test-only'},
        inner: MockClient((r) async {
          expect(r.headers['authorization'], 'Bearer test-only');
          paths.add(r.url.path);
          return r.url.path.endsWith('/20')
              ? http.Response.bytes([1, 2, 3], 200)
              : http.Response(jsonEncode(payload()), 200);
        }),
      );
      final data = RemoteCollection(user, transport: client);
      addTearDown(data.dispose);
      await data.refresh();
      expect(data.desires.single.id, '10');
      expect(data.tapes.single.desireId, '10');
      expect(await data.recording(data.tapes.single), [1, 2, 3]);
      expect(paths, ['/apps/hypnosis/initial', '/hypnosis/recordings/20']);
    },
  );
  test('Failed save keeps existing content and reports failure', () async {
    final client = NexusAuthenticatedClient(
      preset: user.preset,
      userId: user.userId,
      authHeaders: (_) async => {},
      inner: MockClient(
        (r) async => r.method == 'GET'
            ? http.Response(jsonEncode(payload()), 200)
            : http.Response('Unavailable', 503),
      ),
    );
    final data = RemoteCollection(user, transport: client);
    addTearDown(data.dispose);
    await data.refresh();
    await expectLater(
      data.saveDesire('Changed', 'Different', id: '10'),
      throwsException,
    );
    expect(data.desires.single.title, 'Faith');
  });
}
