import 'dart:async';
import 'dart:typed_data';

import 'package:nx_db/auth.dart';
import 'package:nx_utils/nx_utils.dart';

class VoiceSocketSessionConfig {
  const VoiceSocketSessionConfig({
    required this.socketUrl,
    required this.userId,
    required this.clientApp,
    required this.agentId,
  });

  final String socketUrl;
  final String userId;
  final String clientApp;
  final String agentId;

  String get key => '$socketUrl|$userId|$clientApp|$agentId';
}

class VoiceSocketTurn {
  const VoiceSocketTurn({
    required this.streamIndex,
    required this.turn,
  });

  final int streamIndex;
  final NxVoiceAudioTurn turn;
}

abstract interface class VoiceSocketSessionPort {
  set onAudioChunk(void Function(NxVoiceAudioChunk packet)? value);
  set onAudioEof(void Function(NxVoiceAudioEof packet)? value);
  set onTextChunk(void Function(NxVoiceTextChunk packet)? value);
  set onTextEof(void Function(NxVoiceTextEof packet)? value);
  set onError(void Function(Object error)? value);

  bool get isConnected;
  int get streamIndex;
  VoiceSocketTurn? get activeTurn;
  VoiceSocketTurn? get lastTurn;

  Future<void> connect(VoiceSocketSessionConfig config);
  VoiceSocketTurn beginAudioTurn();
  void sendAudioPacket(Uint8List opus);
  void sendAudioPackets(Iterable<Uint8List> packets);
  void endAudioTurn();
  void sendTextTurn(String text);
  Future<void> disconnect({bool clearQueuedPackets = true});
}

class VoiceSocketSession implements VoiceSocketSessionPort {
  VoiceSocketSession({
    NxVoiceSocketClient? socketClient,
  }) : _socket = socketClient ?? NxVoiceSocketClient();

  final NxVoiceSocketClient _socket;

  String? _sessionKey;
  int _streamIndex = 0;
  int _packetIndex = 0;
  VoiceSocketTurn? _activeTurn;
  VoiceSocketTurn? _lastTurn;
  bool _handlersAttached = false;

  void Function(NxVoiceAudioChunk packet)? _onAudioChunk;
  void Function(NxVoiceAudioEof packet)? _onAudioEof;
  void Function(NxVoiceTextChunk packet)? _onTextChunk;
  void Function(NxVoiceTextEof packet)? _onTextEof;
  void Function(Object error)? _onError;

  @override
  set onAudioChunk(void Function(NxVoiceAudioChunk packet)? value) {
    _onAudioChunk = value;
  }

  @override
  set onAudioEof(void Function(NxVoiceAudioEof packet)? value) {
    _onAudioEof = value;
  }

  @override
  set onTextChunk(void Function(NxVoiceTextChunk packet)? value) {
    _onTextChunk = value;
  }

  @override
  set onTextEof(void Function(NxVoiceTextEof packet)? value) {
    _onTextEof = value;
  }

  @override
  set onError(void Function(Object error)? value) {
    _onError = value;
  }

  @override
  bool get isConnected => _socket.isConnected;

  @override
  int get streamIndex => _streamIndex;

  @override
  VoiceSocketTurn? get activeTurn => _activeTurn;

  @override
  VoiceSocketTurn? get lastTurn => _lastTurn;

  @override
  Future<void> connect(VoiceSocketSessionConfig config) async {
    _attachHandlers();
    final key = config.key;
    if (_socket.isConnected && _sessionKey == key) {
      return;
    }

    if (_sessionKey != null && _sessionKey != key) {
      await _socket.disconnect(clearQueuedPackets: true);
    }

    _sessionKey = key;
    final connected = await _socket.connect(
      config.socketUrl,
      headers: _headersFor(config),
    );
    if (!connected) {
      throw StateError('Could not connect to voice socket.');
    }
  }

  @override
  VoiceSocketTurn beginAudioTurn() {
    _streamIndex++;
    _packetIndex = 0;
    final turn = NxVoiceAudioTurn.create(streamIndex: _streamIndex);
    final context = VoiceSocketTurn(streamIndex: _streamIndex, turn: turn);
    _activeTurn = context;
    _lastTurn = context;
    return context;
  }

  @override
  void sendAudioPacket(Uint8List opus) {
    final turn = _activeTurn;
    _socket.sendAudioChunk(
      opus,
      streamIndex: _streamIndex,
      packetIndex: _packetIndex,
      meta: turn?.turn.metaForPacket(_packetIndex),
    );
    _packetIndex++;
  }

  @override
  void sendAudioPackets(Iterable<Uint8List> packets) {
    for (final packet in packets) {
      sendAudioPacket(packet);
    }
  }

  @override
  void endAudioTurn() {
    final turn = _activeTurn;
    _socket.sendAudioEof(
      streamIndex: _streamIndex,
      meta: turn?.turn.metaForPacket(_packetIndex),
    );
    _activeTurn = null;
  }

  @override
  void sendTextTurn(String text) {
    _streamIndex++;
    _activeTurn = null;
    _lastTurn = null;
    _socket.sendTextTurn(text, streamIndex: _streamIndex);
  }

  @override
  Future<void> disconnect({bool clearQueuedPackets = true}) async {
    _activeTurn = null;
    await _socket.disconnect(clearQueuedPackets: clearQueuedPackets);
  }

  void _attachHandlers() {
    if (_handlersAttached) return;
    _handlersAttached = true;
    _socket
      ..onAudioChunk = (packet) {
        _onAudioChunk?.call(packet);
      }
      ..onAudioEof = (packet) {
        _onAudioEof?.call(packet);
      }
      ..onTextChunk = (packet) {
        _onTextChunk?.call(packet);
      }
      ..onTextEof = (packet) {
        _onTextEof?.call(packet);
      }
      ..onError = (error) {
        _onError?.call(error);
      };
  }

  Map<String, String> _headersFor(VoiceSocketSessionConfig config) {
    return <String, String>{
      'X-User-Id': config.userId,
      'X-Client-App': config.clientApp,
      'X-Agent-Id': config.agentId,
      if (CfAccess.shouldAttachHeaders(config.socketUrl)) ...CfAccess.headers,
    };
  }
}
