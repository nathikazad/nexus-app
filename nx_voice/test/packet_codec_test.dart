import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nx_voice/nx_voice.dart';

void main() {
  test('serializes and parses opus audio chunk', () {
    final opus = Uint8List.fromList([1, 2, 3, 4]);
    final raw = NxVoicePacketCodec.serializeAudioChunk(
      opus,
      streamIndex: 7,
      packetIndex: 9,
    );

    expect(raw[0], 0x01);
    expect(raw[1], 0x00);
    expect(ByteData.sublistView(raw).getUint32(2, Endian.little), 7);
    expect(raw[6], 0x01);
    expect(raw[7], 0x00);
    expect(ByteData.sublistView(raw).getUint16(10, Endian.little), 4);

    final parsed = NxVoicePacketCodec.parse(raw);
    expect(parsed, isA<NxVoiceAudioChunk>());
    final audio = parsed as NxVoiceAudioChunk;
    expect(audio.streamIndex, 7);
    expect(audio.turnId, 7);
    expect(audio.packetIndex, 9);
    expect(audio.opus, [1, 2, 3, 4]);
  });

  test('serializes and parses text turn packets', () {
    final raw = NxVoicePacketCodec.serializeTextChunk(
      'hello',
      streamIndex: 2,
    );
    final parsed = NxVoicePacketCodec.parse(raw);

    expect(parsed, isA<NxVoiceTextChunk>());
    expect((parsed as NxVoiceTextChunk).text, 'hello');
    expect(parsed.streamIndex, 2);

    final eof = NxVoicePacketCodec.parse(
      NxVoicePacketCodec.serializeTextEof(streamIndex: 2),
    );
    expect(eof, isA<NxVoiceTextEof>());
    expect((eof as NxVoiceTextEof).streamIndex, 2);
  });

  test('serializes and parses audio eof variants', () {
    final plain = NxVoicePacketCodec.parse(
      NxVoicePacketCodec.serializeAudioEof(streamIndex: 3),
    );
    expect(plain, isA<NxVoiceAudioEof>());
    expect((plain as NxVoiceAudioEof).streamIndex, 3);

    final meta = NxVoicePacketCodec.audioMeta(
      turnRandom: 4,
      turnId: 5,
      packetIndex: 6,
    );
    final wrapped = NxVoicePacketCodec.parse(
      NxVoicePacketCodec.serializeAudioEof(streamIndex: 3, meta: meta),
    );
    expect(wrapped, isA<NxVoiceAudioEof>());
    final eof = wrapped as NxVoiceAudioEof;
    expect(eof.streamIndex, 3);
    expect(eof.turnRandom, 4);
    expect(eof.turnId, 5);
    expect(eof.packetIndex, 6);
  });

  test('audio turn keeps nonce and turn id across packet metadata', () {
    final turn = NxVoiceAudioTurn(streamIndex: 18, turnRandom: 11, turnId: 2);

    final first = NxVoicePacketCodec.parse(
      NxVoicePacketCodec.serializeAudioChunk(
        Uint8List.fromList([1]),
        streamIndex: turn.streamIndex,
        meta: turn.metaForPacket(0),
      ),
    ) as NxVoiceAudioChunk;
    final eof = NxVoicePacketCodec.parse(
      NxVoicePacketCodec.serializeAudioEof(
        streamIndex: turn.streamIndex,
        meta: turn.metaForPacket(9),
      ),
    ) as NxVoiceAudioEof;

    expect(turn.turnkey, '11:2');
    expect(first.turnRandom, 11);
    expect(first.turnId, 2);
    expect(first.packetIndex, 0);
    expect(eof.turnRandom, 11);
    expect(eof.turnId, 2);
    expect(eof.packetIndex, 9);
  });

  test('parses legacy server device request layout', () {
    final payload = utf8.encode(jsonEncode({'action': 'get_gps'}));
    final raw = Uint8List(12 + payload.length);
    final data = ByteData.sublistView(raw);
    data.setUint32(0, 11, Endian.little);
    data.setUint16(4, NxVoicePacketCodec.deviceRequestPacket, Endian.little);
    data.setUint32(6, 22, Endian.little);
    data.setUint16(10, payload.length, Endian.little);
    raw.setRange(12, 12 + payload.length, payload);

    final parsed = NxVoicePacketCodec.parse(raw);
    expect(parsed, isA<NxVoiceDeviceRequest>());
    final request = parsed as NxVoiceDeviceRequest;
    expect(request.streamIndex, 11);
    expect(request.requestId, 22);
    expect(request.action, 'get_gps');
  });
}
