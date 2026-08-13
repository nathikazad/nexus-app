import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'audio/live_audio_player.dart';
import 'input/live_agent_input_controller.dart';
import 'live_agent.dart';
import 'openai_realtime_transport.dart';
import 'transport/realtime_websocket_connector.dart';

/// Realtime WebSocket transport used on macOS so assistant PCM can be queued
/// locally and genuinely resumed from the paused position.
final class OpenAiRealtimeWebSocketTransport
    implements
        LiveAgentTransport,
        LiveAgentInputControlTransport,
        LiveAgentPlaybackControlTransport {
  OpenAiRealtimeWebSocketTransport({
    required LiveRealtimeAudioDevice audioDevice,
    Future<WebSocketChannel> Function({
      required Uri uri,
      required String credential,
    })?
    connectWebSocket,
  }) : _audioDevice = audioDevice,
       _connectWebSocket = connectWebSocket ?? connectRealtimeWebSocket;

  final LiveRealtimeAudioDevice _audioDevice;
  final Future<WebSocketChannel> Function({
    required Uri uri,
    required String credential,
  })
  _connectWebSocket;
  final StreamController<LiveAgentEvent> _events =
      StreamController<LiveAgentEvent>.broadcast();

  WebSocketChannel? _channel;
  Completer<void>? _sessionReady;
  StreamSubscription<Object?>? _socketSubscription;
  Future<void> _sendChain = Future<void>.value();
  Future<void> _outputChain = Future<void>.value();
  bool _closed = true;
  bool _inputEnabled = true;
  bool _emitTranscripts = true;
  bool _responseActive = false;
  bool _responseHadAudio = false;
  bool _discardResponseAudio = false;
  int? _maxConversationPairs;
  final Set<String> _conversationItemIds = <String>{};
  final List<({String id, String role})> _conversationMessages = [];

  @override
  Stream<LiveAgentEvent> get events => _events.stream;

  @override
  Future<void> connect({
    required String credential,
    required LiveAgentSpec spec,
    required List<LiveAgentToolDefinition> tools,
  }) async {
    if (credential.trim().isEmpty) {
      throw StateError('A Realtime credential is required.');
    }
    await close();
    _closed = false;
    _inputEnabled =
        spec.turnDetectionMode == LiveAgentTurnDetectionMode.automatic;
    _emitTranscripts = spec.emitTranscripts;
    _maxConversationPairs = spec.maxConversationPairs;
    _conversationItemIds.clear();
    _conversationMessages.clear();

    _audioDevice.onPlaybackStarted = () {
      _emit(const LiveAgentEvent(LiveAgentEventType.speaking));
    };
    _audioDevice.onPlaybackStopped = () {
      _emit(const LiveAgentEvent(LiveAgentEventType.playbackStopped));
    };

    final channel =
        await _connectWebSocket(
          uri: Uri.parse(
            'wss://api.openai.com/v1/realtime?model=${Uri.encodeQueryComponent(spec.model)}',
          ),
          credential: credential.trim(),
        ).timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw TimeoutException(
            'Timed out connecting to the Realtime WebSocket.',
          ),
        );
    _channel = channel;
    _sessionReady = Completer<void>();
    _socketSubscription = channel.stream.listen(
      _handleSocketData,
      onError: (Object error) => _emit(
        LiveAgentEvent(
          LiveAgentEventType.error,
          text: 'Realtime WebSocket error: $error',
        ),
      ),
      onDone: () {
        if (!_closed) {
          _emit(const LiveAgentEvent(LiveAgentEventType.disconnected));
        }
      },
    );

    final session = openAiRealtimeSession(spec: spec, tools: tools);
    final audio = Map<String, Object?>.from(session['audio']! as Map);
    final input = Map<String, Object?>.from(
      audio['input']! as Map,
    )..['format'] = const <String, Object?>{'type': 'audio/pcm', 'rate': 24000};
    final output = Map<String, Object?>.from(
      audio['output']! as Map,
    )..['format'] = const <String, Object?>{'type': 'audio/pcm', 'rate': 24000};
    audio['input'] = input;
    audio['output'] = output;
    session['audio'] = audio;
    await _send({'type': 'session.update', 'session': session});
    await _sessionReady!.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw TimeoutException(
        'The Realtime server did not confirm the session configuration.',
      ),
    );
    await _startMicrophone().timeout(
      // CoreAudio may take over 20 seconds to wake and bind the built-in input
      // device after sleep even though capture then starts successfully.
      const Duration(seconds: 40),
      onTimeout: () =>
          throw TimeoutException('The macOS microphone stream did not start.'),
    );
    _emit(const LiveAgentEvent(LiveAgentEventType.connected));
  }

  Future<void> _startMicrophone() async {
    _audioDevice.onInputPcm16 = (bytes) {
      if (_closed || !_inputEnabled || bytes.isEmpty) return;
      _enqueueSend({
        'type': 'input_audio_buffer.append',
        'audio': base64Encode(bytes),
      });
    };
    await _audioDevice.startInput();
  }

  @override
  Future<void> sendInstruction(
    String text, {
    bool requestResponse = true,
  }) async {
    await _send({
      'type': 'conversation.item.create',
      'item': {
        'type': 'message',
        'role': 'system',
        'content': [
          {'type': 'input_text', 'text': text},
        ],
      },
    });
    if (requestResponse) await this.requestResponse();
  }

  @override
  Future<void> sendToolResult(String callId, Object? output) => _send({
    'type': 'conversation.item.create',
    'item': {
      'type': 'function_call_output',
      'call_id': callId,
      'output': jsonEncode(output),
    },
  });

  @override
  Future<void> discardConversation({Set<String> keepItemIds = const {}}) async {
    final discarded = <String>[
      for (final itemId in _conversationItemIds)
        if (!keepItemIds.contains(itemId)) itemId,
    ];
    for (final itemId in discarded) {
      await _send({'type': 'conversation.item.delete', 'item_id': itemId});
      _conversationItemIds.remove(itemId);
      _conversationMessages.removeWhere((item) => item.id == itemId);
    }
  }

  @override
  Future<void> requestResponse() async {
    _discardResponseAudio = false;
    await _send({'type': 'response.create'});
  }

  @override
  Future<void> cancelResponse() async {
    _discardResponseAudio = true;
    // Socket callbacks can overlap while PCM method-channel calls are still
    // in flight. Drain every accepted chunk before the final stop so none can
    // reach the native player after its queue has been cleared.
    await _outputChain;
    await _audioDevice.stop();
    if (_responseActive) await _send({'type': 'response.cancel'});
  }

  @override
  Future<void> setAutomaticTurnDetection(bool enabled) =>
      _send(openAiTurnDetectionUpdate(enabled));

  @override
  Future<void> clearInputAudio() => _send({'type': 'input_audio_buffer.clear'});

  @override
  Future<void> commitInputAudio() =>
      _send({'type': 'input_audio_buffer.commit'});

  @override
  Future<void> setInputEnabled(bool enabled) async {
    _inputEnabled = enabled;
    // Closing the gate must flush already-enqueued PCM appends before a
    // following commit can be sent.
    if (!enabled) await _sendChain;
  }

  @override
  Future<void> setPlaybackPaused(bool paused) =>
      paused ? _audioDevice.pause() : _audioDevice.resume();

  void _enqueueSend(Map<String, Object?> event) {
    _sendChain = _sendChain.then((_) => _send(event)).catchError((
      Object error,
    ) {
      _emit(
        LiveAgentEvent(
          LiveAgentEventType.error,
          text: 'Could not send microphone audio: $error',
        ),
      );
    });
  }

  Future<void> _send(Map<String, Object?> event) async {
    final channel = _channel;
    if (channel == null || _closed) {
      throw StateError('The live agent is not connected.');
    }
    channel.sink.add(jsonEncode(event));
  }

  Future<void> _handleSocketData(Object? raw) async {
    try {
      final decoded = jsonDecode(raw.toString());
      if (decoded is! Map) return;
      final event = Map<String, dynamic>.from(decoded);
      _trackConversationItem(event);
      if (event['type'] == 'session.updated' &&
          !(_sessionReady?.isCompleted ?? true)) {
        _sessionReady!.complete();
      } else if (event['type'] == 'error' &&
          !(_sessionReady?.isCompleted ?? true)) {
        final rawError = event['error'];
        final message = rawError is Map
            ? rawError['message']?.toString()
            : rawError?.toString();
        _sessionReady!.completeError(
          StateError(message ?? 'Realtime session configuration failed.'),
        );
      }
      switch (event['type']) {
        case 'response.created':
          _responseActive = true;
          _responseHadAudio = false;
          _discardResponseAudio = false;
        case 'response.output_audio.delta':
          final delta = event['delta'];
          if (delta is String && delta.isNotEmpty) _responseHadAudio = true;
          if (!_discardResponseAudio && delta is String && delta.isNotEmpty) {
            _enqueueOutput(() => _audioDevice.addPcm16(base64Decode(delta)));
          }
        case 'response.output_audio.done':
          if (!_discardResponseAudio) {
            _enqueueOutput(_audioDevice.finishResponse);
          }
        case 'response.done':
          _responseActive = false;
          await _pruneConversationPairs();
      }
      for (final parsed in parseOpenAiRealtimeEvent(event)) {
        if (parsed.type == LiveAgentEventType.speaking) continue;
        // The server can finish generating long before the native PCM queue
        // finishes playing. Keep the session in speaking/paused until the
        // audio device reports playbackStopped.
        if (event['type'] == 'response.done' &&
            _responseHadAudio &&
            parsed.type == LiveAgentEventType.listening) {
          continue;
        }
        if (_emitTranscripts || parsed.type != LiveAgentEventType.transcript) {
          _emit(parsed);
        }
      }
    } catch (error) {
      _emit(
        LiveAgentEvent(
          LiveAgentEventType.error,
          text: 'Invalid Realtime event: $error',
        ),
      );
    }
  }

  void _trackConversationItem(Map<String, dynamic> event) {
    switch (event['type']) {
      case 'conversation.item.created':
      case 'conversation.item.added':
        final item = event['item'];
        if (item is Map) {
          final id = item['id']?.toString();
          if (id != null && id.isNotEmpty) {
            _conversationItemIds.add(id);
            final role = item['role']?.toString();
            if (item['type'] == 'message' &&
                (role == 'user' || role == 'assistant') &&
                !_conversationMessages.any((message) => message.id == id)) {
              _conversationMessages.add((id: id, role: role!));
            }
          }
        }
      case 'conversation.item.deleted':
        if (event['item_id'] case final String id) {
          _conversationItemIds.remove(id);
          _conversationMessages.removeWhere((item) => item.id == id);
        }
    }
  }

  Future<void> _pruneConversationPairs() async {
    final maxPairs = _maxConversationPairs;
    if (maxPairs == null) return;
    final obsolete = conversationItemIdsOutsideRecentPairs(
      _conversationMessages,
      maxPairs,
    );
    for (final itemId in obsolete) {
      await _send({'type': 'conversation.item.delete', 'item_id': itemId});
      _conversationItemIds.remove(itemId);
      _conversationMessages.removeWhere((item) => item.id == itemId);
    }
  }

  void _emit(LiveAgentEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  void _enqueueOutput(Future<void> Function() operation) {
    _outputChain = _outputChain.then((_) => operation()).catchError((
      Object error,
    ) {
      _emit(
        LiveAgentEvent(
          LiveAgentEventType.error,
          text: 'Could not play assistant audio: $error',
        ),
      );
    });
  }

  @override
  Future<void> close() async {
    _closed = true;
    _audioDevice.onInputPcm16 = null;
    await _audioDevice.stopInput();
    await _socketSubscription?.cancel();
    _socketSubscription = null;
    try {
      await _channel?.sink.close().timeout(const Duration(seconds: 2));
    } on TimeoutException {
      // The socket may be half-open while connection setup is being cancelled.
    }
    _channel = null;
    _sessionReady = null;
    await _outputChain;
    await _audioDevice.stop();
  }

  @override
  Future<void> dispose() async {
    await close();
    await _audioDevice.dispose();
    if (!_events.isClosed) await _events.close();
  }
}
