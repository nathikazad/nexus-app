import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint;
import 'necklace_command_handler.dart';
import 'necklace_device_port.dart';
import 'necklace_socket_port.dart';

/// Owns necklace turn forwarding, not BLE connection/retry/write policy.
/// One instance belongs to one background runtime. Session generation prevents
/// late reconnect completions from clearing a newer session's queue.
class NecklaceRelay {
  NecklaceRelay(
      {required this.device,
      required this.socketClient,
      required this.emit,
      required this.currentGeneration});
  final NecklaceDevicePort device;
  final NecklaceSocketPort socketClient;
  final void Function(String, Map<String, dynamic>) emit;
  final int Function() currentGeneration;
  int _packetCount = 0;
  int _imagePacketCount = 0;
  int _audioPacketCount = 0;
  bool _audioSendActive = false;
  int _audioSendPacketCount = 0;
  int _audioSendOpusByteCount = 0;
  int? _audioSendTurnId;
  int? _audioSendNonce;
  bool _audioForwardNoSocketLogged = false;
  bool _audioForwardConnectStarted = false;

  String _utcNow() => DateTime.now().toUtc().toIso8601String();

  void _logAudioForwardEvent({
    required String eventName,
    required String message,
    String? turnkey,
    Map<String, dynamic> payload = const {},
  }) {
    debugPrint(
      '[Audio Forward] $eventName: $message '
      'turnkey=$turnkey state=${socketClient.connectionState.name} '
      'queued=${socketClient.queuedPacketCount} payload=$payload',
    );
  }

  void _ensureSocketForAudioTurn(String? turnkey) {
    final generation = currentGeneration();
    if (socketClient.isConnected) return;
    if (!_audioForwardNoSocketLogged) {
      _audioForwardNoSocketLogged = true;
      final state = socketClient.connectionState.name;
      final turnkeyText = turnkey == null ? '' : ', turnkey=$turnkey';
      _logAudioForwardEvent(
        eventName: 'audio_forward_no_socket',
        message:
            'audio forward has no socket connection$turnkeyText, state=$state',
        turnkey: turnkey,
      );
    }
    if (_audioForwardConnectStarted) return;
    _audioForwardConnectStarted = true;
    final turnkeyText = turnkey == null ? '' : ', turnkey=$turnkey';
    _logAudioForwardEvent(
      eventName: 'audio_forward_connect_started',
      message: 'audio forward socket connect started$turnkeyText',
      turnkey: turnkey,
    );
    unawaited(socketClient
        .ensureConnected(
            reason: 'ble_audio${turnkey == null ? '' : ':$turnkey'}')
        .then((connected) async {
      if (generation != currentGeneration()) return;
      if (connected) {
        _logAudioForwardEvent(
          eventName: 'audio_forward_connect_succeeded',
          message: 'audio forward socket connect succeeded$turnkeyText',
          turnkey: turnkey,
        );
        return;
      }
      final dropped = socketClient.queuedPacketCount;
      socketClient.clearQueue();
      _logAudioForwardEvent(
        eventName: 'audio_forward_connect_failed',
        message:
            'audio forward socket connect failed$turnkeyText, dropped $dropped queued packets',
        turnkey: turnkey,
        payload: {'dropped_packets': dropped},
      );
    }));
  }

  void onAudioPacket(Uint8List data) {
    _packetCount++;
    // ESP32 payload format: [0x01][0x00][meta:2][size:2][opus].
    final packetIndex = data.length >= 4 ? data[2] : 0;
    emit('ble.packet', {
      'count': _packetCount,
      'packet_index': packetIndex,
      'size': data.length,
    });

    final isAudioEof = data.length >= 2 && data[0] == 0xFC && data[1] == 0xFF;
    if (!_audioSendActive) {
      _audioSendActive = true;
      _audioSendPacketCount = 0;
      _audioSendOpusByteCount = 0;
      _audioSendTurnId = null;
      _audioSendNonce = null;
      _audioForwardNoSocketLogged = false;
      _audioForwardConnectStarted = false;
      debugPrint("[BLE BG] ${_utcNow()} UTC nrf opus reception started");
    }
    if (!isAudioEof) {
      _audioSendPacketCount++;
      _audioSendOpusByteCount += _opusBytesFromNrfAudioPayload(data);
      _audioSendTurnId ??= _turnIdFromNrfAudioPayload(data);
      _audioSendNonce ??= _nonceFromNrfAudioPayload(data);
    }
    final currentTurnkey = _turnkey(_audioSendNonce, _audioSendTurnId);
    _ensureSocketForAudioTurn(currentTurnkey);

    // Forward BLE payload with 4B index (consistent with text/image/EOF)
    _audioPacketCount++;
    final sendStatus = socketClient.sendPacket(data, index: _audioPacketCount);
    if (sendStatus == SocketSendStatus.queuedAfterSendFailure) {
      _logAudioForwardEvent(
        eventName: 'audio_forward_send_failed',
        message:
            'audio forward socket send failed, queued packet for reconnect${currentTurnkey == null ? '' : ', turnkey=$currentTurnkey'}',
        turnkey: currentTurnkey,
      );
      _ensureSocketForAudioTurn(currentTurnkey);
    }
    if (isAudioEof) {
      final turnText =
          _audioSendTurnId == null ? "" : ", turn_id=$_audioSendTurnId";
      final nonceText =
          _audioSendNonce == null ? "" : ", nonce=$_audioSendNonce";
      final turnkey = _turnkey(_audioSendNonce, _audioSendTurnId);
      final turnkeyText = turnkey == null ? "" : ", turnkey=$turnkey";
      final message =
          'nrf opus reception finished $_audioSendPacketCount packets, $_audioSendOpusByteCount bytes$turnText$nonceText$turnkeyText';
      debugPrint(
        "[BLE BG] ${_utcNow()} UTC $message",
      );
      if (!socketClient.isConnected) {
        _logAudioForwardEvent(
          eventName: 'audio_forward_eof_no_socket',
          message:
              'audio forward reached EOF without socket connection$turnkeyText',
          turnkey: turnkey,
          payload: {
            'opus_packets': _audioSendPacketCount,
            'opus_bytes': _audioSendOpusByteCount,
            if (_audioSendTurnId != null) 'turn_id': _audioSendTurnId,
            if (_audioSendNonce != null) 'nonce': _audioSendNonce,
          },
        );
      }
      _audioSendActive = false;
    }
    // Send ACK back to the device
    device.sendAudio(Uint8List.fromList([0x41, 0x43, 0x4B])); // "ACK" in ASCII
  }

  void attachSocket() {
    // Forward packets from server to BLE
    socketClient.onPacketFromServer = (packet) => device.sendAudio(packet);
    socketClient.onAudioReceptionSummary = (summary) {
      final packets = summary['opus_packets'];
      final bytes = summary['opus_bytes'];
      final turnId = summary['turn_id'];
      final nonce = summary['nonce'];
      final turnkey = summary['turnkey'];
      final turnText = turnId == null ? '' : ', turn_id=$turnId';
      final nonceText = nonce == null ? '' : ', nonce=$nonce';
      final turnkeyText = turnkey == null ? '' : ', turnkey=$turnkey';
      debugPrint(
        'websocket opus reception finished $packets packets, $bytes bytes$turnText$nonceText$turnkeyText',
      );
    };

    // Handle device requests (e.g. take_photo, camera record)
    socketClient.onDeviceRequest = NecklaceCommandHandler(
      device,
    ).handle;
  }

  void onImagePacket(Uint8List data) {
    _imagePacketCount++;
    socketClient.sendImagePacket(data, _imagePacketCount);
  }
}

int _opusBytesFromNrfAudioPayload(Uint8List data) {
  if (data.length >= 6 && data[0] == 0x01 && data[1] == 0x00) {
    final declared = data[4] | (data[5] << 8);
    final available = data.length - 6;
    if (declared >= 0 && declared <= available) return declared;
  }
  if (data.length >= 4) {
    final declared = data[2] | (data[3] << 8);
    final available = data.length - 4;
    if (declared >= 0 && declared <= available) return declared;
  }
  return data.length;
}

int? _turnIdFromNrfAudioPayload(Uint8List data) {
  if (data.length >= 6 && data[0] == 0x01 && data[1] == 0x00) {
    final declared = data[4] | (data[5] << 8);
    if (declared + 6 != data.length) return null;
    final meta = data[2] | (data[3] << 8);
    return (meta >> 8) & 0x0F;
  }
  if (data.length >= 4) {
    final declared = data[2] | (data[3] << 8);
    if (declared + 4 != data.length) return null;
    final meta = data[0] | (data[1] << 8);
    return (meta >> 8) & 0x0F;
  }
  return null;
}

int? _nonceFromNrfAudioPayload(Uint8List data) {
  if (data.length >= 6 && data[0] == 0x01 && data[1] == 0x00) {
    final declared = data[4] | (data[5] << 8);
    if (declared + 6 != data.length) return null;
    final meta = data[2] | (data[3] << 8);
    return (meta >> 12) & 0x0F;
  }
  if (data.length >= 4) {
    final declared = data[2] | (data[3] << 8);
    if (declared + 4 != data.length) return null;
    final meta = data[0] | (data[1] << 8);
    return (meta >> 12) & 0x0F;
  }
  return null;
}

String? _turnkey(int? nonce, int? turnId) {
  if (nonce == null || turnId == null) return null;
  return '$nonce:$turnId';
}
