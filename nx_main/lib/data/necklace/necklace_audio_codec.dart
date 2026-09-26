import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint;

/// Stateful server-to-necklace framing. Only validated audio reaches BLE.
/// Transport disconnect must reset this instance before another session.
class NecklaceAudioCodec {
  static const _opusAudioPacket = 1;
  static const _audioEofPacket = 0xfffc;
  void Function(Map<String, dynamic>)? onAudioReceptionSummary;
  bool _audioReceiveActive = false;
  int _audioReceivePacketCount = 0;
  int _audioReceiveOpusByteCount = 0;
  int? _audioReceiveTurnId;
  int? _audioReceiveNonce;
  int? _audioReceiveMeta;
  void reset() {
    _audioReceiveActive = false;
  }

  Uint8List? decode(Uint8List packet) {
    if (packet.length < 2) return null;

    final byteData = ByteData.sublistView(packet);
    final headerType = byteData.getUint16(0, Endian.little);

    if (headerType == _audioEofPacket) {
      // No invented 0:0 turn for empty or malformed responses.
      if (packet.length != 6 || !_audioReceiveActive) return null;
      final meta = _audioReceiveMeta!;
      _finishAudioReception();
      return Uint8List.fromList([
        _audioEofPacket & 0xFF,
        (_audioEofPacket >> 8) & 0xFF,
        meta & 0xFF,
        (meta >> 8) & 0xFF,
      ]);
    }

    if (headerType != _opusAudioPacket || packet.length < 12) {
      return null;
    }

    final meta = byteData.getUint16(8, Endian.little);
    final opusSize = byteData.getUint16(10, Endian.little);
    final opusStart = 12;
    final opusEnd = opusStart + opusSize;
    if (opusSize == 0 || opusEnd != packet.length) {
      debugPrint(
        "[Socket] Invalid server audio packet: size $opusSize, expected $opusEnd got ${packet.length}",
      );
      return null;
    }
    _recordAudioReception(
      opusBytes: opusSize,
      turnId: (meta >> 8) & 0x0F,
      meta: meta,
    );

    final blePayload = Uint8List(4 + opusSize);
    final out = ByteData.sublistView(blePayload);
    out.setUint16(0, meta, Endian.little);
    out.setUint16(2, opusSize, Endian.little);
    blePayload.setRange(4, 4 + opusSize, packet, opusStart);
    return blePayload;
  }

  String _utcNow() => DateTime.now().toUtc().toIso8601String();

  void _recordAudioReception({required int opusBytes, int? turnId, int? meta}) {
    if (!_audioReceiveActive) {
      _audioReceiveActive = true;
      _audioReceivePacketCount = 0;
      _audioReceiveOpusByteCount = 0;
      _audioReceiveTurnId = null;
      _audioReceiveNonce = null;
      _audioReceiveMeta = null;
      debugPrint("[BLE BG] ${_utcNow()} UTC websocket opus reception started");
    }
    _audioReceivePacketCount++;
    _audioReceiveOpusByteCount += opusBytes;
    _audioReceiveTurnId ??= turnId;
    _audioReceiveNonce ??= meta == null ? null : ((meta >> 12) & 0x0F);
    _audioReceiveMeta ??= meta;
  }

  void _finishAudioReception() {
    if (!_audioReceiveActive) return;
    final turnText =
        _audioReceiveTurnId == null ? "" : ", turn_id=$_audioReceiveTurnId";
    final nonceText =
        _audioReceiveNonce == null ? "" : ", nonce=$_audioReceiveNonce";
    final turnkey = _audioReceiveNonce == null || _audioReceiveTurnId == null
        ? null
        : "$_audioReceiveNonce:$_audioReceiveTurnId";
    final turnkeyText = turnkey == null ? "" : ", turnkey=$turnkey";
    debugPrint(
      "[BLE BG] ${_utcNow()} UTC websocket opus reception finished "
      "$_audioReceivePacketCount packets, $_audioReceiveOpusByteCount bytes$turnText$nonceText$turnkeyText",
    );
    onAudioReceptionSummary?.call({
      'opus_packets': _audioReceivePacketCount,
      'opus_bytes': _audioReceiveOpusByteCount,
      if (_audioReceiveTurnId != null) 'turn_id': _audioReceiveTurnId,
      if (_audioReceiveNonce != null) 'nonce': _audioReceiveNonce,
      if (turnkey != null) 'turnkey': turnkey,
    });
    _audioReceiveActive = false;
    _audioReceivePacketCount = 0;
    _audioReceiveOpusByteCount = 0;
    _audioReceiveTurnId = null;
    _audioReceiveNonce = null;
    _audioReceiveMeta = null;
  }
}
