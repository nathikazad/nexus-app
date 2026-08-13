import 'dart:async';
import 'dart:convert';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;
import 'package:nx_live_agent/src/live_agent.dart';

void initializeLiveAgentPlatform() {
  FlutterForegroundTask.initCommunicationPort();
}

final class OpenAiRealtimeTransport
    implements
        LiveAgentTransport,
        LiveAgentInputControlTransport,
        LiveAgentPlaybackControlTransport {
  OpenAiRealtimeTransport({http.Client? httpClient})
    : _http = httpClient ?? http.Client(),
      _ownsHttpClient = httpClient == null;

  final http.Client _http;
  final bool _ownsHttpClient;
  final StreamController<LiveAgentEvent> _events =
      StreamController<LiveAgentEvent>.broadcast();

  RTCPeerConnection? _peerConnection;
  RTCDataChannel? _dataChannel;
  MediaStream? _localStream;
  final List<MediaStreamTrack> _remoteAudioTracks = <MediaStreamTrack>[];
  Completer<void>? _dataChannelReady;
  bool _closed = false;
  final Set<String> _conversationItemIds = <String>{};
  final List<({String id, String role})> _conversationMessages = [];
  bool _emitTranscripts = true;
  int? _maxConversationPairs;

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
    _conversationItemIds.clear();
    _conversationMessages.clear();
    _remoteAudioTracks.clear();
    _emitTranscripts = spec.emitTranscripts;
    _maxConversationPairs = spec.maxConversationPairs;
    await _configureAudioSession();
    await _startAndroidForegroundService();

    final peer = await createPeerConnection({'sdpSemantics': 'unified-plan'});
    _peerConnection = peer;
    peer.onConnectionState = (state) {
      if (_closed) return;
      switch (state) {
        case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
          _emit(const LiveAgentEvent(LiveAgentEventType.connected));
        case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
            RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
            RTCPeerConnectionState.RTCPeerConnectionStateClosed:
          _emit(const LiveAgentEvent(LiveAgentEventType.disconnected));
        default:
          break;
      }
    };
    peer.onTrack = (event) {
      if (event.track.kind == 'audio') {
        event.track.enabled = true;
        _remoteAudioTracks.add(event.track);
      }
    };

    final stream = await navigator.mediaDevices.getUserMedia({
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      },
      'video': false,
    });
    _localStream = stream;
    for (final track in stream.getAudioTracks()) {
      await peer.addTrack(track, stream);
    }

    _dataChannelReady = Completer<void>();
    final channel = await peer.createDataChannel(
      'oai-events',
      RTCDataChannelInit()..ordered = true,
    );
    _dataChannel = channel;
    channel.onDataChannelState = (state) {
      if (state == RTCDataChannelState.RTCDataChannelOpen &&
          !(_dataChannelReady?.isCompleted ?? true)) {
        _dataChannelReady!.complete();
      }
    };
    channel.onMessage = (message) {
      if (!message.isBinary) unawaited(_handleMessage(message.text));
    };

    final offer = await peer.createOffer();
    await peer.setLocalDescription(offer);
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('https://api.openai.com/v1/realtime/calls'),
    );
    request.headers['Authorization'] = 'Bearer ${credential.trim()}';
    request.fields['session'] = jsonEncode(
      openAiRealtimeSession(spec: spec, tools: tools),
    );
    request.fields['sdp'] = offer.sdp ?? '';
    final streamedResponse = await _http.send(request);
    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = _openAiErrorDetail(response.body);
      throw StateError(
        'Could not start live agent (HTTP ${response.statusCode})$detail.',
      );
    }
    await peer.setRemoteDescription(
      RTCSessionDescription(response.body, 'answer'),
    );
    await _dataChannelReady!.future.timeout(const Duration(seconds: 15));
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
  Future<void> sendToolResult(String callId, Object? output) {
    return _send({
      'type': 'conversation.item.create',
      'item': {
        'type': 'function_call_output',
        'call_id': callId,
        'output': jsonEncode(output),
      },
    });
  }

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
  Future<void> requestResponse() => _send({'type': 'response.create'});

  @override
  Future<void> cancelResponse() => _send({'type': 'response.cancel'});

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
    for (final track
        in _localStream?.getAudioTracks() ?? <MediaStreamTrack>[]) {
      track.enabled = enabled;
    }
  }

  @override
  Future<void> setPlaybackPaused(bool paused) async {
    for (final track in _remoteAudioTracks) {
      track.enabled = !paused;
    }
  }

  Future<void> _send(Map<String, Object?> event) async {
    final channel = _dataChannel;
    if (channel == null) throw StateError('The live agent is not connected.');
    await _dataChannelReady?.future;
    await channel.send(RTCDataChannelMessage(jsonEncode(event)));
  }

  Future<void> _handleMessage(String raw) async {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final event = Map<String, dynamic>.from(decoded);
      _trackConversationItem(event);
      if (event['type'] == 'response.done') {
        await _pruneConversationPairs();
      }
      for (final parsed in parseOpenAiRealtimeEvent(event)) {
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

  @override
  Future<void> close() async {
    _closed = true;
    final stream = _localStream;
    _localStream = null;
    if (stream != null) {
      for (final track in stream.getTracks()) {
        await track.stop();
      }
      await stream.dispose();
    }
    await _dataChannel?.close();
    _dataChannel = null;
    await _peerConnection?.close();
    _peerConnection = null;
    _dataChannelReady = null;
    _remoteAudioTracks.clear();
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await FlutterForegroundTask.stopService();
    }
    try {
      final audioSession = await AudioSession.instance;
      await audioSession.setActive(false);
    } catch (_) {
      // Connection setup may have failed before the audio session activated.
    }
  }

  @override
  Future<void> dispose() async {
    await close();
    if (_ownsHttpClient) _http.close();
    if (!_events.isClosed) await _events.close();
  }
}

String _openAiErrorDetail(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map && decoded['error'] is Map) {
      final message = (decoded['error'] as Map)['message']?.toString().trim();
      if (message?.isNotEmpty == true) return ': $message';
    }
  } catch (_) {
    // The error body may be plain text rather than JSON.
  }
  final normalized = body.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (normalized.isEmpty) return '';
  final end = normalized.length > 240 ? 240 : normalized.length;
  return ': ${normalized.substring(0, end)}';
}

Map<String, Object?> openAiRealtimeSession({
  required LiveAgentSpec spec,
  required List<LiveAgentToolDefinition> tools,
}) => <String, Object?>{
  'type': 'realtime',
  'model': spec.model,
  'instructions': spec.instructions,
  'audio': {
    'input': {
      'noise_reduction': {'type': 'near_field'},
      if (spec.enableInputTranscription)
        'transcription': {'model': 'gpt-4o-mini-transcribe'},
      'turn_detection': {...openAiSemanticVad()},
    },
    'output': {'voice': spec.voice},
  },
  'tools': [for (final tool in tools) tool.toJson()],
  'tool_choice': 'auto',
};

Map<String, Object?> openAiSemanticVad() => const <String, Object?>{
  'type': 'semantic_vad',
  'eagerness': 'medium',
  'create_response': true,
  'interrupt_response': true,
};

Map<String, Object?> openAiTurnDetectionUpdate(bool enabled) =>
    <String, Object?>{
      'type': 'session.update',
      'session': {
        'type': 'realtime',
        'audio': {
          'input': {'turn_detection': enabled ? openAiSemanticVad() : null},
        },
      },
    };

List<String> conversationItemIdsOutsideRecentPairs(
  List<({String id, String role})> messages,
  int maxPairs,
) {
  if (maxPairs <= 0) return [for (final message in messages) message.id];
  final userIndexes = <int>[
    for (var index = 0; index < messages.length; index += 1)
      if (messages[index].role == 'user') index,
  ];
  if (userIndexes.length <= maxPairs) return const [];
  final firstRetainedUserIndex = userIndexes[userIndexes.length - maxPairs];
  return [
    for (final message in messages.take(firstRetainedUserIndex)) message.id,
  ];
}

List<LiveAgentEvent> parseOpenAiRealtimeEvent(Map<String, dynamic> event) {
  switch (event['type']) {
    case 'input_audio_buffer.speech_started':
      return const [LiveAgentEvent(LiveAgentEventType.userSpeechStarted)];
    case 'input_audio_buffer.speech_stopped':
    case 'response.created':
      return const [LiveAgentEvent(LiveAgentEventType.thinking)];
    case 'response.output_audio.delta':
    case 'output_audio_buffer.started':
      return const [LiveAgentEvent(LiveAgentEventType.speaking)];
    case 'output_audio_buffer.stopped':
      return const [LiveAgentEvent(LiveAgentEventType.playbackStopped)];
    case 'response.output_audio_transcript.delta':
      final delta = event['delta']?.toString();
      return delta == null || delta.isEmpty
          ? const []
          : [
              LiveAgentEvent(
                LiveAgentEventType.transcript,
                role: 'assistant',
                text: delta,
              ),
            ];
    case 'conversation.item.input_audio_transcription.completed':
      final transcript = event['transcript']?.toString();
      final usage = _transcriptionUsageFromEvent(event['usage']);
      return [
        if (usage != null)
          LiveAgentEvent(LiveAgentEventType.usage, usage: usage),
        if (transcript != null && transcript.isNotEmpty)
          LiveAgentEvent(
            LiveAgentEventType.transcript,
            role: 'user',
            text: transcript,
          ),
      ];
    case 'response.done':
      final usage = _usageFromResponse(event['response']);
      final toolCalls = _toolCallsFromResponse(event['response']);
      return [
        if (usage != null)
          LiveAgentEvent(LiveAgentEventType.usage, usage: usage),
        if (toolCalls.isEmpty)
          const LiveAgentEvent(LiveAgentEventType.listening)
        else
          ...toolCalls,
      ];
    case 'error':
      final error = event['error'];
      final message = error is Map
          ? error['message']?.toString()
          : error?.toString();
      return [
        LiveAgentEvent(
          LiveAgentEventType.error,
          text: message ?? 'Realtime error',
        ),
      ];
    default:
      return const [];
  }
}

LiveAgentUsage? _usageFromResponse(Object? rawResponse) {
  if (rawResponse is! Map || rawResponse['usage'] is! Map) return null;
  final usage = rawResponse['usage'] as Map;
  final inputDetails = usage['input_token_details'] is Map
      ? usage['input_token_details'] as Map
      : const <Object?, Object?>{};
  final cachedDetails = inputDetails['cached_tokens_details'] is Map
      ? inputDetails['cached_tokens_details'] as Map
      : const <Object?, Object?>{};
  final outputDetails = usage['output_token_details'] is Map
      ? usage['output_token_details'] as Map
      : const <Object?, Object?>{};
  return LiveAgentUsage(
    inputTokens: _tokenCount(usage['input_tokens']),
    outputTokens: _tokenCount(usage['output_tokens']),
    inputTextTokens: _tokenCount(inputDetails['text_tokens']),
    inputAudioTokens: _tokenCount(inputDetails['audio_tokens']),
    cachedInputTokens: _tokenCount(inputDetails['cached_tokens']),
    cachedInputTextTokens: _tokenCount(cachedDetails['text_tokens']),
    cachedInputAudioTokens: _tokenCount(cachedDetails['audio_tokens']),
    outputTextTokens: _tokenCount(outputDetails['text_tokens']),
    outputAudioTokens: _tokenCount(outputDetails['audio_tokens']),
  );
}

LiveAgentUsage? _transcriptionUsageFromEvent(Object? rawUsage) {
  if (rawUsage is! Map) return null;
  return LiveAgentUsage(
    transcriptionInputTokens: _tokenCount(rawUsage['input_tokens']),
    transcriptionOutputTokens: _tokenCount(rawUsage['output_tokens']),
  );
}

int _tokenCount(Object? value) => switch (value) {
  int count => count,
  num count => count.toInt(),
  _ => int.tryParse(value?.toString() ?? '') ?? 0,
};

List<LiveAgentEvent> _toolCallsFromResponse(Object? rawResponse) {
  if (rawResponse is! Map || rawResponse['output'] is! List) return const [];
  final result = <LiveAgentEvent>[];
  for (final rawItem in rawResponse['output'] as List) {
    if (rawItem is! Map || rawItem['type'] != 'function_call') continue;
    final name = rawItem['name']?.toString();
    final callId = rawItem['call_id']?.toString();
    if (name == null || name.isEmpty || callId == null || callId.isEmpty) {
      continue;
    }
    try {
      final decoded = jsonDecode(rawItem['arguments']?.toString() ?? '{}');
      if (decoded is! Map) continue;
      result.add(
        LiveAgentEvent(
          LiveAgentEventType.toolCall,
          toolCall: LiveAgentToolCall(
            callId: callId,
            name: name,
            arguments: Map<String, Object?>.from(decoded),
            itemId: rawItem['id']?.toString(),
          ),
        ),
      );
    } catch (_) {
      continue;
    }
  }
  return result;
}

Future<void> _configureAudioSession() async {
  final session = await AudioSession.instance;
  await session.configure(
    AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
      avAudioSessionCategoryOptions:
          AVAudioSessionCategoryOptions.defaultToSpeaker |
          AVAudioSessionCategoryOptions.allowBluetooth,
      avAudioSessionMode: AVAudioSessionMode.voiceChat,
      androidAudioAttributes: const AndroidAudioAttributes(
        contentType: AndroidAudioContentType.speech,
        usage: AndroidAudioUsage.voiceCommunication,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      androidWillPauseWhenDucked: false,
    ),
  );
  await session.setActive(true);
}

Future<void> _startAndroidForegroundService() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'nexus_live_agent',
      channelName: 'Live voice agent',
      channelDescription: 'Keeps an active Nexus voice session running.',
      onlyAlertOnce: true,
    ),
    iosNotificationOptions: const IOSNotificationOptions(
      showNotification: false,
      playSound: false,
    ),
    foregroundTaskOptions: ForegroundTaskOptions(
      eventAction: ForegroundTaskEventAction.nothing(),
      allowWakeLock: true,
      allowWifiLock: true,
    ),
  );
  if (await FlutterForegroundTask.isRunningService) return;
  final permission = await FlutterForegroundTask.checkNotificationPermission();
  if (permission != NotificationPermission.granted) {
    await FlutterForegroundTask.requestNotificationPermission();
  }
  final result = await FlutterForegroundTask.startService(
    serviceId: 4312,
    serviceTypes: const [
      ForegroundServiceTypes.microphone,
      ForegroundServiceTypes.mediaPlayback,
    ],
    notificationTitle: 'Voice session active',
    notificationText: 'Listening for your response',
    callback: _liveAgentTaskCallback,
  );
  if (result is ServiceRequestFailure) throw result.error;
}

@pragma('vm:entry-point')
void _liveAgentTaskCallback() {
  FlutterForegroundTask.setTaskHandler(_LiveAgentTaskHandler());
}

final class _LiveAgentTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}
