import 'dart:typed_data';

import 'package:nx_voice/nx_voice.dart';

class NoteAiSessionConfig {
  const NoteAiSessionConfig({
    required this.socketUrl,
    required this.userId,
    required this.documentId,
    required this.authHeaders,
  });

  final String socketUrl;
  final String userId;
  final int documentId;
  final Future<Map<String, String>> Function(bool forceRefresh) authHeaders;

  String get key => '$socketUrl|$userId|$documentId';

  Map<String, String> get headers => <String, String>{
    'X-Client-App': 'nx_notes',
    'X-Agent-Id': 'nx_notes',
    'X-Document-Id': documentId.toString(),
  };
}

abstract interface class NoteAiSocketPort {
  set onAudioChunk(void Function(NxVoiceAudioChunk packet)? value);
  set onAudioEof(void Function(NxVoiceAudioEof packet)? value);
  set onTextChunk(void Function(NxVoiceTextChunk packet)? value);
  set onTextEof(void Function(NxVoiceTextEof packet)? value);
  set onError(void Function(Object error)? value);

  bool get isConnected;

  Future<bool> connect(
    String url, {
    required Map<String, String> headers,
    required Future<Map<String, String>> Function(bool forceRefresh)
    authHeaders,
  });
  Future<void> disconnect({bool clearQueuedPackets = true});
  void sendAudioChunk(
    Uint8List opus, {
    required int streamIndex,
    required int packetIndex,
    int? meta,
  });
  void sendAudioEof({required int streamIndex, int? meta});
  void sendTextTurn(String text, {required int streamIndex});
}

class NxNoteAiSocketPort implements NoteAiSocketPort {
  NxNoteAiSocketPort([NxVoiceSocketClient? socket])
    : _socket = socket ?? NxVoiceSocketClient();

  final NxVoiceSocketClient _socket;

  @override
  set onAudioChunk(void Function(NxVoiceAudioChunk packet)? value) =>
      _socket.onAudioChunk = value;

  @override
  set onAudioEof(void Function(NxVoiceAudioEof packet)? value) =>
      _socket.onAudioEof = value;

  @override
  set onTextChunk(void Function(NxVoiceTextChunk packet)? value) =>
      _socket.onTextChunk = value;

  @override
  set onTextEof(void Function(NxVoiceTextEof packet)? value) =>
      _socket.onTextEof = value;

  @override
  set onError(void Function(Object error)? value) => _socket.onError = value;

  @override
  bool get isConnected => _socket.isConnected;

  @override
  Future<bool> connect(
    String url, {
    required Map<String, String> headers,
    required Future<Map<String, String>> Function(bool forceRefresh)
    authHeaders,
  }) => _socket.connect(url, headers: headers, authHeaders: authHeaders);

  @override
  Future<void> disconnect({bool clearQueuedPackets = true}) =>
      _socket.disconnect(clearQueuedPackets: clearQueuedPackets);

  @override
  void sendAudioChunk(
    Uint8List opus, {
    required int streamIndex,
    required int packetIndex,
    int? meta,
  }) => _socket.sendAudioChunk(
    opus,
    streamIndex: streamIndex,
    packetIndex: packetIndex,
    meta: meta,
  );

  @override
  void sendAudioEof({required int streamIndex, int? meta}) =>
      _socket.sendAudioEof(streamIndex: streamIndex, meta: meta);

  @override
  void sendTextTurn(String text, {required int streamIndex}) =>
      _socket.sendTextTurn(text, streamIndex: streamIndex);
}

class NoteAiSession {
  NoteAiSession({NoteAiSocketPort? socket})
    : _socket = socket ?? NxNoteAiSocketPort();

  final NoteAiSocketPort _socket;
  String? _sessionKey;
  int _streamIndex = 0;
  int _packetIndex = 0;
  NxVoiceAudioTurn? _activeAudioTurn;

  int get streamIndex => _streamIndex;

  set onAudioChunk(void Function(NxVoiceAudioChunk packet)? value) =>
      _socket.onAudioChunk = value;

  set onAudioEof(void Function(NxVoiceAudioEof packet)? value) =>
      _socket.onAudioEof = value;

  set onTextChunk(void Function(NxVoiceTextChunk packet)? value) =>
      _socket.onTextChunk = value;

  set onTextEof(void Function(NxVoiceTextEof packet)? value) =>
      _socket.onTextEof = value;

  set onError(void Function(Object error)? value) => _socket.onError = value;

  Future<void> connect(NoteAiSessionConfig config) async {
    if (config.documentId <= 0) {
      throw ArgumentError.value(
        config.documentId,
        'documentId',
        'must be positive',
      );
    }
    if (_socket.isConnected && _sessionKey == config.key) return;
    if (_sessionKey != null && _sessionKey != config.key) {
      await _socket.disconnect(clearQueuedPackets: true);
    }
    final connected = await _socket.connect(
      config.socketUrl,
      headers: config.headers,
      authHeaders: config.authHeaders,
    );
    if (!connected) {
      throw StateError('Could not connect to the Nx Docs AI socket.');
    }
    _sessionKey = config.key;
  }

  void sendTextTurn(String text) {
    final normalized = text.trim();
    if (normalized.isEmpty) return;
    _streamIndex++;
    _activeAudioTurn = null;
    _socket.sendTextTurn(normalized, streamIndex: _streamIndex);
  }

  void beginAudioTurn() {
    _streamIndex++;
    _packetIndex = 0;
    _activeAudioTurn = NxVoiceAudioTurn.create(streamIndex: _streamIndex);
  }

  void sendAudioPacket(Uint8List opus) {
    final turn = _activeAudioTurn;
    if (turn == null) {
      throw StateError('No active Nx Docs audio turn.');
    }
    _socket.sendAudioChunk(
      opus,
      streamIndex: _streamIndex,
      packetIndex: _packetIndex,
      meta: turn.metaForPacket(_packetIndex),
    );
    _packetIndex++;
  }

  void endAudioTurn() {
    final turn = _activeAudioTurn;
    if (turn == null) return;
    _socket.sendAudioEof(
      streamIndex: _streamIndex,
      meta: turn.metaForPacket(_packetIndex),
    );
    _activeAudioTurn = null;
  }

  Future<void> disconnect() async {
    _activeAudioTurn = null;
    _sessionKey = null;
    await _socket.disconnect(clearQueuedPackets: true);
  }
}
