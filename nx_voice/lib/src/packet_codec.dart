import 'dart:convert';
import 'dart:typed_data';

enum NxVoicePacketType {
  opusAudio(0x0001),
  text(0x0002),
  image(0x0003),
  deviceRequest(0x0004),
  deviceResponse(0x0005),
  textEof(0x0006),
  audioEof(0xFFFC);

  const NxVoicePacketType(this.value);

  final int value;

  static NxVoicePacketType? fromValue(int value) {
    for (final type in values) {
      if (type.value == value) return type;
    }
    return null;
  }
}

sealed class NxVoicePacket {
  const NxVoicePacket();
}

class NxVoiceAudioChunk extends NxVoicePacket {
  const NxVoiceAudioChunk({
    required this.opus,
    required this.streamIndex,
    required this.packetIndex,
    required this.meta,
    required this.turnRandom,
    required this.turnId,
  });

  final Uint8List opus;
  final int streamIndex;
  final int packetIndex;
  final int meta;
  final int turnRandom;
  final int turnId;
}

class NxVoiceAudioEof extends NxVoicePacket {
  const NxVoiceAudioEof({
    required this.streamIndex,
    this.meta = 0,
    this.turnRandom = 0,
    this.turnId = 0,
    this.packetIndex = 0,
  });

  final int streamIndex;
  final int meta;
  final int turnRandom;
  final int turnId;
  final int packetIndex;
}

class NxVoiceTextChunk extends NxVoicePacket {
  const NxVoiceTextChunk({
    required this.text,
    required this.streamIndex,
  });

  final String text;
  final int streamIndex;
}

class NxVoiceTextEof extends NxVoicePacket {
  const NxVoiceTextEof({required this.streamIndex});

  final int streamIndex;
}

class NxVoiceDeviceRequest extends NxVoicePacket {
  const NxVoiceDeviceRequest({
    required this.requestId,
    required this.action,
    required this.params,
    required this.payload,
    required this.streamIndex,
  });

  final int requestId;
  final String action;
  final Map<String, dynamic> params;
  final Map<String, dynamic> payload;
  final int streamIndex;
}

class NxVoiceUnknownPacket extends NxVoicePacket {
  const NxVoiceUnknownPacket(this.bytes);

  final Uint8List bytes;
}

class NxVoicePacketCodec {
  static const int opusAudioPacket = 0x0001;
  static const int textPacket = 0x0002;
  static const int deviceRequestPacket = 0x0004;
  static const int deviceResponsePacket = 0x0005;
  static const int textEofPacket = 0x0006;
  static const int audioEofPacket = 0xFFFC;

  static int audioMeta({
    required int turnRandom,
    required int turnId,
    required int packetIndex,
  }) {
    return ((turnRandom & 0x0F) << 12) |
        ((turnId & 0x0F) << 8) |
        (packetIndex & 0xFF);
  }

  static Uint8List serializeAudioChunk(
    Uint8List opus, {
    int streamIndex = 0,
    int packetIndex = 0,
    int? meta,
  }) {
    final resolvedMeta = meta ??
        audioMeta(
          turnRandom: 0,
          turnId: streamIndex & 0x0F,
          packetIndex: packetIndex,
        );
    final packet = Uint8List(12 + opus.length);
    final data = ByteData.sublistView(packet);
    data.setUint16(0, opusAudioPacket, Endian.little);
    data.setUint32(2, streamIndex, Endian.little);
    packet[6] = 0x01;
    packet[7] = 0x00;
    data.setUint16(8, resolvedMeta & 0xFFFF, Endian.little);
    data.setUint16(10, opus.length, Endian.little);
    packet.setRange(12, 12 + opus.length, opus);
    return packet;
  }

  static Uint8List serializeAudioEof({
    int streamIndex = 0,
    int? meta,
  }) {
    if (meta == null) {
      final packet = Uint8List(6);
      final data = ByteData.sublistView(packet);
      data.setUint16(0, audioEofPacket, Endian.little);
      data.setUint32(2, streamIndex, Endian.little);
      return packet;
    }

    final packet = Uint8List(10);
    final data = ByteData.sublistView(packet);
    data.setUint16(0, opusAudioPacket, Endian.little);
    data.setUint32(2, streamIndex, Endian.little);
    data.setUint16(6, audioEofPacket, Endian.little);
    data.setUint16(8, meta & 0xFFFF, Endian.little);
    return packet;
  }

  static Uint8List serializeTextChunk(
    String text, {
    int streamIndex = 0,
  }) {
    final bytes = Uint8List.fromList(utf8.encode(text));
    final packet = Uint8List(8 + bytes.length);
    final data = ByteData.sublistView(packet);
    data.setUint16(0, textPacket, Endian.little);
    data.setUint32(2, streamIndex, Endian.little);
    data.setUint16(6, bytes.length, Endian.little);
    packet.setRange(8, 8 + bytes.length, bytes);
    return packet;
  }

  static Uint8List serializeTextEof({int streamIndex = 0}) {
    final packet = Uint8List(6);
    final data = ByteData.sublistView(packet);
    data.setUint16(0, textEofPacket, Endian.little);
    data.setUint32(2, streamIndex, Endian.little);
    return packet;
  }

  static Uint8List serializeDeviceResponse({
    required int requestId,
    required String payload,
    int streamIndex = 0,
  }) {
    final bytes = Uint8List.fromList(utf8.encode(payload));
    final packet = Uint8List(12 + bytes.length);
    final data = ByteData.sublistView(packet);
    data.setUint16(0, deviceResponsePacket, Endian.little);
    data.setUint32(2, streamIndex, Endian.little);
    data.setUint32(6, requestId, Endian.little);
    data.setUint16(10, bytes.length, Endian.little);
    packet.setRange(12, 12 + bytes.length, bytes);
    return packet;
  }

  static NxVoicePacket? parse(Uint8List message) {
    if (message.length < 6) return null;

    final data = ByteData.sublistView(message);
    final header = data.getUint16(0, Endian.little);
    final streamIndex = data.getUint32(2, Endian.little);

    if (header == textEofPacket) {
      return NxVoiceTextEof(streamIndex: streamIndex);
    }

    if (header == audioEofPacket) {
      return NxVoiceAudioEof(streamIndex: streamIndex);
    }

    if (header == opusAudioPacket && message.length >= 8) {
      final payload16 = data.getUint16(6, Endian.little);
      if (payload16 == audioEofPacket) {
        final meta =
            message.length >= 10 ? data.getUint16(8, Endian.little) : 0;
        return NxVoiceAudioEof(
          streamIndex: streamIndex,
          meta: meta,
          turnRandom: (meta >> 12) & 0x0F,
          turnId: (meta >> 8) & 0x0F,
          packetIndex: meta & 0xFF,
        );
      }
    }

    if (header == opusAudioPacket && message.length >= 12) {
      final meta = data.getUint16(8, Endian.little);
      final size = data.getUint16(10, Endian.little);
      final end = 12 + size;
      if (end == message.length) {
        return NxVoiceAudioChunk(
          opus: Uint8List.sublistView(message, 12, end),
          streamIndex: streamIndex,
          packetIndex: meta & 0xFF,
          meta: meta,
          turnRandom: (meta >> 12) & 0x0F,
          turnId: (meta >> 8) & 0x0F,
        );
      }
    }

    if (header == textPacket && message.length >= 8) {
      final size = data.getUint16(6, Endian.little);
      final end = 8 + size;
      if (end <= message.length) {
        return NxVoiceTextChunk(
          text: utf8.decode(message.sublist(8, end)),
          streamIndex: streamIndex,
        );
      }
    }

    final deviceRequest = _tryParseDeviceRequest(message);
    if (deviceRequest != null) return deviceRequest;

    return NxVoiceUnknownPacket(message);
  }

  static NxVoiceDeviceRequest? _tryParseDeviceRequest(Uint8List message) {
    if (message.length < 12) return null;
    final data = ByteData.sublistView(message);

    // Server-to-client device requests use the legacy layout:
    // [stream_index 4][DEVICE_REQUEST 2][request_id 4][size 2][json].
    final header = data.getUint16(4, Endian.little);
    if (header != deviceRequestPacket) return null;

    final streamIndex = data.getUint32(0, Endian.little);
    final requestId = data.getUint32(6, Endian.little);
    final size = data.getUint16(10, Endian.little);
    final end = 12 + size;
    if (end > message.length) return null;

    final decoded = jsonDecode(utf8.decode(message.sublist(12, end)));
    if (decoded is! Map<String, dynamic>) return null;
    final action = decoded['action'];
    if (action is! String) return null;

    return NxVoiceDeviceRequest(
      requestId: requestId,
      action: action,
      params: decoded,
      payload: decoded,
      streamIndex: streamIndex,
    );
  }
}
