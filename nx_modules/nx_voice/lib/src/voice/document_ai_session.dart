import 'dart:typed_data';
import 'dart:convert';

import 'packet_codec.dart';
import 'socket_client.dart';

class DocumentConversation {
  const DocumentConversation({required this.transcriptId, this.context = ''});
  final int transcriptId;
  final String context;
}

class DocumentAiSessionConfig {
  const DocumentAiSessionConfig({
    required this.socketUrl,
    required this.userId,
    this.domainId,
    this.transcriptId,
    required this.authHeaders,
    this.clientId = 'nx_docs',
    this.loadConversation,
  });
  final String socketUrl;
  final String userId;
  final int? domainId;
  final int? transcriptId;
  final String clientId;
  final Future<Map<String, String>> Function(bool forceRefresh) authHeaders;
  final Future<DocumentConversation> Function()? loadConversation;
  String get key => '$socketUrl|$userId|$domainId|$clientId|$transcriptId';
  Map<String, String> get headers => {
        'X-Client-Id': clientId,
        if (domainId != null) 'X-Domain-Id': '$domainId',
        if (transcriptId != null) 'X-Transcript-Id': '$transcriptId',
      };
}

abstract interface class DocumentAiSocketPort {
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
  void sendContext(String input, String context);
}

class NxDocumentAiSocketPort implements DocumentAiSocketPort {
  NxDocumentAiSocketPort([NxVoiceSocketClient? socket])
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
  }) =>
      _socket.connect(url, headers: headers, authHeaders: authHeaders);

  @override
  Future<void> disconnect({bool clearQueuedPackets = true}) =>
      _socket.disconnect(clearQueuedPackets: clearQueuedPackets);

  @override
  void sendAudioChunk(
    Uint8List opus, {
    required int streamIndex,
    required int packetIndex,
    int? meta,
  }) =>
      _socket.sendAudioChunk(
        opus,
        streamIndex: streamIndex,
        packetIndex: packetIndex,
        meta: meta,
      );

  @override
  void sendAudioEof({required int streamIndex, int? meta}) =>
      _socket.sendAudioEof(streamIndex: streamIndex, meta: meta);

  @override
  void sendContext(String input, String context) => _socket
      .sendEvent({'type': 'input_context', 'input': input, 'context': context});

  @override
  void sendTextTurn(String text, {required int streamIndex}) =>
      _socket.sendTextTurn(text, streamIndex: streamIndex);
}

class DocumentAiSession {
  DocumentAiSession({DocumentAiSocketPort? socket})
      : _socket = socket ?? NxDocumentAiSocketPort();

  final DocumentAiSocketPort _socket;
  String? _sessionKey;
  String _referenceContext = '';
  int _generation = 0;
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

  Future<void> connect(DocumentAiSessionConfig config) async {
    final generation = ++_generation;
    if ((config.domainId != null && config.domainId! <= 0) ||
        (config.transcriptId != null && config.transcriptId! <= 0)) {
      throw ArgumentError('Domain and transcript IDs must be positive');
    }
    final conversation = await config.loadConversation?.call();
    if (generation != _generation) throw StateError('Session closed');
    final transcriptId = conversation?.transcriptId ?? config.transcriptId;
    if (transcriptId != null && transcriptId <= 0)
      throw StateError('Invalid transcript');
    _referenceContext = conversation?.context ?? '';
    final key = '${config.key}|$transcriptId';
    if (_socket.isConnected && _sessionKey == key) return;
    if (_sessionKey != null) await _socket.disconnect(clearQueuedPackets: true);
    if (generation != _generation) throw StateError('Session closed');
    final connected = await _socket.connect(
      config.socketUrl,
      headers: {
        ...config.headers,
        if (transcriptId != null) 'X-Transcript-Id': '$transcriptId'
      },
      authHeaders: config.authHeaders,
    );
    if (!connected) {
      throw StateError(
        'Could not connect to the document assistant AI socket.',
      );
    }
    if (generation != _generation) {
      await _socket.disconnect();
      throw StateError('Session closed');
    }
    _sessionKey = key;
  }

  void sendTextTurn(String text,
      {String context = '', bool preserveContext = false}) {
    final normalized = text.trim();
    if (normalized.isEmpty) return;
    _streamIndex++;
    _activeAudioTurn = null;
    _socket.sendContext(
        'text', _turnContext(context, preserveContext: preserveContext));
    _socket.sendTextTurn(normalized, streamIndex: _streamIndex);
  }

  String _turnContext(String context, {bool preserveContext = false}) {
    final text =
        [context, _referenceContext].where((s) => s.isNotEmpty).join('\n\n');
    if (preserveContext) {
      if (utf8.encode(text).length > 65536) {
        throw StateError('This article exceeds the conversation context limit. '
            'The full article could not be sent; no partial article was used.');
      }
      return text;
    }
    return text.runes.length <= 15000
        ? text
        : '${String.fromCharCodes(text.runes.take(15000))}\n[Context truncated]';
  }

  void beginAudioTurn({String context = '', bool preserveContext = false}) {
    _socket.sendContext(
        'audio', _turnContext(context, preserveContext: preserveContext));
    _streamIndex++;
    _packetIndex = 0;
    _activeAudioTurn = NxVoiceAudioTurn.create(streamIndex: _streamIndex);
  }

  void sendAudioPacket(Uint8List opus) {
    final turn = _activeAudioTurn;
    if (turn == null) {
      throw StateError('No active document assistant audio turn.');
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
    _generation++;
    _referenceContext = '';
    _activeAudioTurn = null;
    _sessionKey = null;
    await _socket.disconnect(clearQueuedPackets: true);
  }
}
