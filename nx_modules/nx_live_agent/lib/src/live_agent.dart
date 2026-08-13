import 'dart:async';

import 'package:flutter/foundation.dart';

import 'input/live_agent_input_controller.dart';
import 'session/live_agent_control_state.dart';

enum LiveAgentPhase {
  idle,
  connecting,
  listening,
  thinking,
  speaking,
  paused,
  closed,
  error,
}

enum LiveAgentEventType {
  connected,
  userSpeechStarted,
  listening,
  thinking,
  speaking,
  playbackStopped,
  transcript,
  usage,
  toolCall,
  disconnected,
  error,
}

final class LiveAgentUsage {
  const LiveAgentUsage({
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.inputTextTokens = 0,
    this.inputAudioTokens = 0,
    this.cachedInputTokens = 0,
    this.cachedInputTextTokens = 0,
    this.cachedInputAudioTokens = 0,
    this.outputTextTokens = 0,
    this.outputAudioTokens = 0,
    this.transcriptionInputTokens = 0,
    this.transcriptionOutputTokens = 0,
  });

  final int inputTokens;
  final int outputTokens;
  final int inputTextTokens;
  final int inputAudioTokens;
  final int cachedInputTokens;
  final int cachedInputTextTokens;
  final int cachedInputAudioTokens;
  final int outputTextTokens;
  final int outputAudioTokens;
  final int transcriptionInputTokens;
  final int transcriptionOutputTokens;

  int get billedInputTokens => inputTokens + transcriptionInputTokens;
  int get billedOutputTokens => outputTokens + transcriptionOutputTokens;
  int get totalTokens => billedInputTokens + billedOutputTokens;

  LiveAgentUsage operator +(LiveAgentUsage other) => LiveAgentUsage(
    inputTokens: inputTokens + other.inputTokens,
    outputTokens: outputTokens + other.outputTokens,
    inputTextTokens: inputTextTokens + other.inputTextTokens,
    inputAudioTokens: inputAudioTokens + other.inputAudioTokens,
    cachedInputTokens: cachedInputTokens + other.cachedInputTokens,
    cachedInputTextTokens: cachedInputTextTokens + other.cachedInputTextTokens,
    cachedInputAudioTokens:
        cachedInputAudioTokens + other.cachedInputAudioTokens,
    outputTextTokens: outputTextTokens + other.outputTextTokens,
    outputAudioTokens: outputAudioTokens + other.outputAudioTokens,
    transcriptionInputTokens:
        transcriptionInputTokens + other.transcriptionInputTokens,
    transcriptionOutputTokens:
        transcriptionOutputTokens + other.transcriptionOutputTokens,
  );
}

final class LiveAgentToolCall {
  const LiveAgentToolCall({
    required this.callId,
    required this.name,
    required this.arguments,
    this.itemId,
  });

  final String callId;
  final String name;
  final Map<String, Object?> arguments;
  final String? itemId;
}

final class LiveAgentEvent {
  const LiveAgentEvent(
    this.type, {
    this.role,
    this.text,
    this.toolCall,
    this.usage,
  });

  final LiveAgentEventType type;
  final String? role;
  final String? text;
  final LiveAgentToolCall? toolCall;
  final LiveAgentUsage? usage;
}

final class LiveAgentToolDefinition {
  const LiveAgentToolDefinition({
    required this.name,
    required this.description,
    required this.parameters,
  });

  final String name;
  final String description;
  final Map<String, Object?> parameters;

  Map<String, Object?> toJson() => <String, Object?>{
    'type': 'function',
    'name': name,
    'description': description,
    'parameters': parameters,
  };
}

final class LiveAgentToolResult {
  const LiveAgentToolResult(
    this.output, {
    this.requestResponse = true,
    this.discardConversationBeforeResponse = false,
  });

  final Object? output;
  final bool requestResponse;
  final bool discardConversationBeforeResponse;
}

abstract interface class LiveAgentTool {
  LiveAgentToolDefinition get definition;

  Future<LiveAgentToolResult> invoke(Map<String, Object?> arguments);
}

final class CallbackLiveAgentTool implements LiveAgentTool {
  const CallbackLiveAgentTool({
    required this.definition,
    required this.onInvoke,
  });

  @override
  final LiveAgentToolDefinition definition;
  final FutureOr<LiveAgentToolResult> Function(Map<String, Object?> arguments)
  onInvoke;

  @override
  Future<LiveAgentToolResult> invoke(Map<String, Object?> arguments) async =>
      onInvoke(arguments);
}

final class LiveAgentSpec {
  const LiveAgentSpec({
    required this.instructions,
    this.initialContext,
    this.model = 'gpt-realtime',
    this.voice = 'marin',
    this.enableInputTranscription = true,
    this.emitTranscripts = true,
    this.maxConversationPairs,
  }) : assert(maxConversationPairs == null || maxConversationPairs > 0);

  final String instructions;
  final String? initialContext;
  final String model;
  final String voice;
  final bool enableInputTranscription;
  final bool emitTranscripts;
  final int? maxConversationPairs;
}

abstract interface class LiveAgentCredentialProvider {
  Future<String> credential();
}

final class StaticLiveAgentCredentialProvider
    implements LiveAgentCredentialProvider {
  const StaticLiveAgentCredentialProvider(this.value);

  final String value;

  @override
  Future<String> credential() async {
    final normalized = value.trim();
    if (normalized.isEmpty || normalized == 'PASTE_OPENAI_API_KEY_HERE') {
      throw StateError('A live-agent credential is not configured.');
    }
    return normalized;
  }
}

abstract interface class LiveAgentTransport {
  Stream<LiveAgentEvent> get events;

  Future<void> connect({
    required String credential,
    required LiveAgentSpec spec,
    required List<LiveAgentToolDefinition> tools,
  });

  Future<void> sendInstruction(String text, {bool requestResponse = true});

  Future<void> sendToolResult(String callId, Object? output);

  Future<void> discardConversation({Set<String> keepItemIds = const {}});

  Future<void> requestResponse();

  Future<void> cancelResponse();

  Future<void> close();

  Future<void> dispose();
}

/// Input operations are intentionally separate from assistant playback.
abstract interface class LiveAgentInputControlTransport {
  Future<void> setAutomaticTurnDetection(bool enabled);
  Future<void> clearInputAudio();
  Future<void> commitInputAudio();
  Future<void> setInputEnabled(bool enabled);
}

/// Optional transport capability for pausing output without ending a response.
abstract interface class LiveAgentPlaybackControlTransport {
  Future<void> setPlaybackPaused(bool paused);
}

final class LiveAgentSession extends ChangeNotifier {
  LiveAgentSession({required LiveAgentTransport transport})
    : _transport = transport,
      inputController = LiveAgentInputController(
        setInputEnabled: (enabled) =>
            _requireInputControl(transport).setInputEnabled(enabled),
        setAutomaticTurnDetection: (enabled) =>
            _requireInputControl(transport).setAutomaticTurnDetection(enabled),
        clearInputAudio: () =>
            _requireInputControl(transport).clearInputAudio(),
        commitInputAudio: () =>
            _requireInputControl(transport).commitInputAudio(),
        requestResponse: transport.requestResponse,
      ) {
    inputController.addListener(_notify);
  }

  final LiveAgentTransport _transport;
  final LiveAgentInputController inputController;
  final Set<String> _handledCallIds = <String>{};
  StreamSubscription<LiveAgentEvent>? _subscription;
  Map<String, LiveAgentTool> _tools = const <String, LiveAgentTool>{};
  bool _disposed = false;
  bool _closeAfterNextPlayback = false;
  bool _expectsInitialResponse = false;
  LiveAgentPhase _phaseBeforePause = LiveAgentPhase.listening;

  LiveAgentPhase phase = LiveAgentPhase.idle;
  bool get muted => inputController.automaticMuted;
  LiveAgentPlaybackState playbackState = LiveAgentPlaybackState.playing;
  String transcript = '';
  String latestUserTranscript = '';
  String latestAssistantTranscript = '';
  String? error;
  int interruptionCount = 0;
  int playbackCompletionCount = 0;
  LiveAgentUsage usage = const LiveAgentUsage();

  Future<void> start({
    required LiveAgentCredentialProvider credentialProvider,
    required LiveAgentSpec spec,
    required List<LiveAgentTool> tools,
  }) async {
    await _subscription?.cancel();
    _handledCallIds.clear();
    _tools = <String, LiveAgentTool>{
      for (final tool in tools) tool.definition.name: tool,
    };
    transcript = '';
    latestUserTranscript = '';
    latestAssistantTranscript = '';
    error = null;
    interruptionCount = 0;
    playbackCompletionCount = 0;
    usage = const LiveAgentUsage();
    _closeAfterNextPlayback = false;
    _expectsInitialResponse = spec.initialContext?.trim().isNotEmpty == true;
    _phaseBeforePause = LiveAgentPhase.listening;
    playbackState = LiveAgentPlaybackState.playing;
    inputController.reset();
    phase = LiveAgentPhase.connecting;
    _notify();
    _subscription = _transport.events.listen(
      (event) => unawaited(_handleEvent(event)),
    );
    try {
      final credential = await credentialProvider.credential();
      await _transport.connect(
        credential: credential,
        spec: spec,
        tools: <LiveAgentToolDefinition>[
          for (final tool in tools) tool.definition,
        ],
      );
      if (spec.initialContext case final context?
          when context.trim().isNotEmpty) {
        await _transport.sendInstruction(context);
      }
    } catch (caught) {
      _fail(caught);
    }
  }

  Future<void> _handleEvent(LiveAgentEvent event) async {
    if (_disposed) return;
    if (phase == LiveAgentPhase.error &&
        event.type != LiveAgentEventType.error) {
      return;
    }
    switch (event.type) {
      case LiveAgentEventType.connected:
        phase = _expectsInitialResponse
            ? LiveAgentPhase.thinking
            : LiveAgentPhase.listening;
      case LiveAgentEventType.userSpeechStarted:
        if (phase == LiveAgentPhase.speaking) interruptionCount += 1;
        latestAssistantTranscript = '';
        if (phase != LiveAgentPhase.paused) phase = LiveAgentPhase.listening;
      case LiveAgentEventType.listening:
        if (phase != LiveAgentPhase.paused) {
          phase = LiveAgentPhase.listening;
        }
      case LiveAgentEventType.thinking:
        if (phase == LiveAgentPhase.paused) {
          _phaseBeforePause = LiveAgentPhase.thinking;
        } else {
          phase = LiveAgentPhase.thinking;
        }
      case LiveAgentEventType.speaking:
        if (phase == LiveAgentPhase.paused) {
          _phaseBeforePause = LiveAgentPhase.speaking;
        } else {
          phase = LiveAgentPhase.speaking;
        }
      case LiveAgentEventType.playbackStopped:
        playbackCompletionCount += 1;
        if (phase == LiveAgentPhase.paused) {
          _phaseBeforePause = LiveAgentPhase.listening;
        } else {
          phase = LiveAgentPhase.listening;
        }
        if (_closeAfterNextPlayback) {
          _closeAfterNextPlayback = false;
          await stop();
          return;
        }
      case LiveAgentEventType.transcript:
        final text = event.text;
        if (text?.isNotEmpty == true) {
          if (event.role == 'user') {
            latestUserTranscript = text!;
            latestAssistantTranscript = '';
            if (transcript.isNotEmpty && !transcript.endsWith('\n')) {
              transcript += '\n';
            }
            transcript += 'You: $text\n';
          } else {
            latestAssistantTranscript += text!;
            transcript += text;
          }
        }
      case LiveAgentEventType.usage:
        if (event.usage case final delta?) usage += delta;
      case LiveAgentEventType.toolCall:
        final call = event.toolCall;
        if (call != null) await _invokeTool(call);
      case LiveAgentEventType.disconnected:
        if (phase != LiveAgentPhase.closed) {
          _fail('The live-agent connection ended.');
        }
      case LiveAgentEventType.error:
        _fail(event.text ?? 'The live agent reported an error.');
    }
    _notify();
  }

  Future<void> _invokeTool(LiveAgentToolCall call) async {
    if (!_handledCallIds.add(call.callId)) return;
    phase = LiveAgentPhase.thinking;
    _notify();
    final tool = _tools[call.name];
    if (tool == null) {
      await _transport.sendToolResult(call.callId, <String, Object?>{
        'ok': false,
        'error': 'Unknown tool: ${call.name}',
      });
      await _transport.requestResponse();
      return;
    }
    try {
      final result = await tool.invoke(call.arguments);
      if (result.discardConversationBeforeResponse) {
        await _transport.discardConversation(
          keepItemIds: <String>{if (call.itemId != null) call.itemId!},
        );
      }
      await _transport.sendToolResult(call.callId, result.output);
      if (result.requestResponse) await _transport.requestResponse();
    } catch (caught) {
      await _transport.sendToolResult(call.callId, <String, Object?>{
        'ok': false,
        'error': caught.toString(),
      });
      await _transport.requestResponse();
    }
  }

  Future<void> sendInstruction(String text, {bool requestResponse = true}) =>
      _transport.sendInstruction(text, requestResponse: requestResponse);

  Future<void> discardConversation({Set<String> keepItemIds = const {}}) =>
      _transport.discardConversation(keepItemIds: keepItemIds);

  void closeAfterNextPlayback() => _closeAfterNextPlayback = true;

  Future<void> interruptResponse() => _transport.cancelResponse();

  Future<void> setPaused(bool paused) async {
    try {
      if (paused) {
        if (playbackState == LiveAgentPlaybackState.paused) return;
        _phaseBeforePause = phase;
        await _requirePlaybackControl(_transport).setPlaybackPaused(true);
        await inputController.setSuspended(true);
        playbackState = LiveAgentPlaybackState.paused;
        phase = LiveAgentPhase.paused;
      } else {
        if (playbackState == LiveAgentPlaybackState.playing) return;
        await _requirePlaybackControl(_transport).setPlaybackPaused(false);
        await inputController.setSuspended(false);
        playbackState = LiveAgentPlaybackState.playing;
        phase = _phaseBeforePause;
      }
    } catch (caught) {
      _fail(caught);
      return;
    }
    _notify();
  }

  Future<void> toggleTurnDetection() async {
    try {
      await inputController.toggleTurnDetection();
    } catch (caught) {
      _fail(caught);
    }
  }

  Future<void> activateMicrophone() async {
    try {
      await inputController.activateMicrophone();
    } catch (caught) {
      _fail(caught);
      return;
    }
    if (inputController.turnDetection == LiveAgentTurnDetectionMode.manual &&
        inputController.inputState == LiveAgentInputState.inactive) {
      phase = LiveAgentPhase.thinking;
      _notify();
    }
  }

  Future<void> stop() async {
    _closeAfterNextPlayback = false;
    phase = LiveAgentPhase.closed;
    _notify();
    await _subscription?.cancel();
    _subscription = null;
    await _transport.close();
  }

  void _fail(Object caught) {
    error = caught.toString().replaceFirst('StateError: ', '');
    phase = LiveAgentPhase.error;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    inputController.removeListener(_notify);
    inputController.dispose();
    unawaited(_subscription?.cancel());
    unawaited(_transport.dispose());
    super.dispose();
  }
}

LiveAgentInputControlTransport _requireInputControl(
  LiveAgentTransport transport,
) {
  if (transport case final LiveAgentInputControlTransport capable) {
    return capable;
  }
  throw UnsupportedError(
    'This live-agent transport cannot control audio input.',
  );
}

LiveAgentPlaybackControlTransport _requirePlaybackControl(
  LiveAgentTransport transport,
) {
  if (transport case final LiveAgentPlaybackControlTransport capable) {
    return capable;
  }
  throw UnsupportedError('This live-agent transport cannot pause playback.');
}
