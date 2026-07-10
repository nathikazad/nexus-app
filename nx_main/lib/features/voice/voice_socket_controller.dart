import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_voice_assistant/data/voice/voice_socket_session.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_utils/nx_utils.dart';

enum VoiceSocketPhase {
  idle,
  connecting,
  recording,
  waiting,
  responding,
  error,
}

class VoiceOverlayMessage {
  const VoiceOverlayMessage({
    required this.role,
    required this.text,
    this.turnkey,
    this.ephemeral = false,
    this.links = const [],
  });

  final String role;
  final String text;
  final String? turnkey;
  final bool ephemeral;
  final List<VoiceAppLink> links;

  bool get fromUser => role == 'user';

  VoiceOverlayMessage copyWith({
    String? text,
    String? turnkey,
    bool? ephemeral,
    List<VoiceAppLink>? links,
  }) {
    return VoiceOverlayMessage(
      role: role,
      text: text ?? this.text,
      turnkey: turnkey ?? this.turnkey,
      ephemeral: ephemeral ?? this.ephemeral,
      links: links ?? this.links,
    );
  }
}

class VoiceAppLink {
  const VoiceAppLink({
    required this.label,
    required this.url,
    this.kind = 'app_route',
    this.routeName,
  });

  factory VoiceAppLink.fromJson(Map<dynamic, dynamic> json) {
    return VoiceAppLink(
      label: (json['label'] ?? 'Open view').toString(),
      url: (json['url'] ?? '').toString(),
      kind: (json['kind'] ?? 'app_route').toString(),
      routeName: json['route_name']?.toString(),
    );
  }

  final String label;
  final String url;
  final String kind;
  final String? routeName;
}

class VoiceSocketState {
  const VoiceSocketState({
    required this.phase,
    this.error,
    this.overlayVisible = false,
    this.messages = const [],
  });

  const VoiceSocketState.idle() : this(phase: VoiceSocketPhase.idle);

  final VoiceSocketPhase phase;
  final String? error;
  final bool overlayVisible;
  final List<VoiceOverlayMessage> messages;

  bool get active => switch (phase) {
        VoiceSocketPhase.connecting ||
        VoiceSocketPhase.recording ||
        VoiceSocketPhase.waiting ||
        VoiceSocketPhase.responding =>
          true,
        VoiceSocketPhase.idle || VoiceSocketPhase.error => false,
      };

  VoiceSocketState copyWith({
    VoiceSocketPhase? phase,
    String? error,
    bool clearError = false,
    bool? overlayVisible,
    List<VoiceOverlayMessage>? messages,
  }) {
    return VoiceSocketState(
      phase: phase ?? this.phase,
      error: clearError ? null : error ?? this.error,
      overlayVisible: overlayVisible ?? this.overlayVisible,
      messages: messages ?? this.messages,
    );
  }
}

final voiceSocketControllerProvider =
    NotifierProvider<VoiceSocketController, VoiceSocketState>(
  VoiceSocketController.new,
);

class VoiceSocketController extends Notifier<VoiceSocketState> {
  VoiceSocketSession? _voiceSession;
  NxMicrophoneOpusStreamer? _mic;
  NxWavAudioPlayer? _player;
  NxAppLogUploader? _appLogUploader;
  int _streamIndex = 0;
  int _sentPacketsThisTurn = 0;
  int _sentBytesThisTurn = 0;
  int _receivedPacketsThisTurn = 0;
  int _receivedBytesThisTurn = 0;
  VoiceSocketTurn? _activeTurn;
  VoiceSocketTurn? _lastTurn;
  bool _stopInFlight = false;
  bool _showOverlayForCurrentTurn = true;
  Timer? _textIdleTimer;

  @override
  VoiceSocketState build() {
    ref.onDispose(() {
      _textIdleTimer?.cancel();
      unawaited(_mic?.dispose());
      unawaited(_player?.dispose());
      unawaited(_voiceSession?.disconnect());
    });
    return const VoiceSocketState.idle();
  }

  void dismissOverlay() {
    state = state.copyWith(overlayVisible: false, clearError: true);
  }

  Future<void> startRecording() async {
    if (state.phase == VoiceSocketPhase.recording ||
        state.phase == VoiceSocketPhase.connecting) {
      return;
    }

    final userId = ref.read(userIdProvider);
    final socketUrl = ref.read(sockWsUrlProvider);
    if (userId == null || userId.isEmpty || socketUrl == null) {
      state = const VoiceSocketState(
        phase: VoiceSocketPhase.error,
        overlayVisible: true,
        error: 'Not logged in or missing socket URL.',
      );
      return;
    }

    state = const VoiceSocketState(
      phase: VoiceSocketPhase.connecting,
      overlayVisible: true,
    );
    try {
      final session = await _ensureVoiceSession(
        socketUrl: socketUrl,
        userId: userId,
      );
      final mic = _mic ??= NxMicrophoneOpusStreamer();
      _sentPacketsThisTurn = 0;
      _sentBytesThisTurn = 0;
      _receivedPacketsThisTurn = 0;
      _receivedBytesThisTurn = 0;
      _activeTurn = session.beginAudioTurn();
      _lastTurn = _activeTurn;
      _streamIndex = _activeTurn!.streamIndex;
      _stopInFlight = false;
      _showOverlayForCurrentTurn = true;
      _textIdleTimer?.cancel();

      final started = await mic.start(
        onOpusPacket: (opus) {
          _sentPacketsThisTurn++;
          _sentBytesThisTurn += opus.length;
          session.sendAudioPacket(opus);
        },
        onError: (error) {
          state = state.copyWith(
            phase: VoiceSocketPhase.error,
            overlayVisible: true,
            error: error.toString(),
          );
        },
      );

      if (!started) {
        _activeTurn = null;
        state = state.copyWith(
          phase: VoiceSocketPhase.error,
          overlayVisible: true,
          error: 'Could not start microphone recording.',
        );
        return;
      }

      _uploadAppLog(
        eventName: 'mic_record_start',
        category: 'audio',
        message: 'nx_main mic recording started',
        payload: {'stream_index': _streamIndex, ..._turnPayload(_activeTurn)},
      );
      state = state.copyWith(
        phase: VoiceSocketPhase.recording,
        overlayVisible: true,
        clearError: true,
      );
    } catch (error) {
      _activeTurn = null;
      state = state.copyWith(
        phase: VoiceSocketPhase.error,
        overlayVisible: true,
        error: error.toString(),
      );
    }
  }

  Future<void> stopRecording() async {
    if (_stopInFlight || state.phase != VoiceSocketPhase.recording) {
      return;
    }
    _stopInFlight = true;
    state = state.copyWith(
      phase: VoiceSocketPhase.waiting,
      overlayVisible: true,
    );

    try {
      final session = _voiceSession;
      final mic = _mic;
      final turn = _activeTurn;
      if (session == null || mic == null) {
        state = state.copyWith(phase: VoiceSocketPhase.idle);
        return;
      }

      final remaining = await mic.stop();
      for (final opus in remaining) {
        _sentPacketsThisTurn++;
        _sentBytesThisTurn += opus.length;
        session.sendAudioPacket(opus);
      }
      session.endAudioTurn();
      _uploadAppLog(
        eventName: 'socket_audio_sent_summary',
        category: 'audio',
        message:
            'nx_main sent $_sentPacketsThisTurn opus packets, $_sentBytesThisTurn bytes',
        payload: {
          'stream_index': _streamIndex,
          'opus_packets': _sentPacketsThisTurn,
          'opus_bytes': _sentBytesThisTurn,
          ..._turnPayload(turn),
        },
      );
      _uploadAppLog(
        eventName: 'mic_record_stop',
        category: 'audio',
        message: 'nx_main mic recording stopped',
        payload: {
          'stream_index': _streamIndex,
          'opus_packets': _sentPacketsThisTurn,
          'opus_bytes': _sentBytesThisTurn,
          ..._turnPayload(turn),
        },
      );
    } catch (error) {
      state = state.copyWith(
        phase: VoiceSocketPhase.error,
        overlayVisible: true,
        error: error.toString(),
      );
    } finally {
      _stopInFlight = false;
      _activeTurn = null;
    }
  }

  Future<void> sendTextMessage(String raw) async {
    final text = raw.trim();
    if (text.isEmpty) return;
    if (state.phase == VoiceSocketPhase.recording ||
        state.phase == VoiceSocketPhase.connecting) {
      throw StateError('Voice socket is busy.');
    }

    final userId = ref.read(userIdProvider);
    final socketUrl = ref.read(sockWsUrlProvider);
    if (userId == null || userId.isEmpty || socketUrl == null) {
      state = const VoiceSocketState(
        phase: VoiceSocketPhase.error,
        overlayVisible: true,
        error: 'Not logged in or missing socket URL.',
      );
      throw StateError('Not logged in or missing socket URL.');
    }

    state =
        state.copyWith(phase: VoiceSocketPhase.connecting, clearError: true);
    try {
      final session = await _ensureVoiceSession(
        socketUrl: socketUrl,
        userId: userId,
      );
      _receivedPacketsThisTurn = 0;
      _receivedBytesThisTurn = 0;
      _showOverlayForCurrentTurn = false;
      _textIdleTimer?.cancel();
      _lastTurn = null;
      _applyTranscript(
        role: 'user',
        text: text,
        turnkey: null,
        showOverlay: false,
      );
      session.sendTextTurn(text);
      _streamIndex = session.streamIndex;
      _uploadAppLog(
        eventName: 'socket_text_sent',
        category: 'audio',
        message: text,
        payload: {
          'stream_index': _streamIndex,
          'text': text,
        },
      );
      state = state.copyWith(phase: VoiceSocketPhase.waiting, clearError: true);
    } catch (error) {
      state = state.copyWith(
        phase: VoiceSocketPhase.error,
        overlayVisible: false,
        error: error.toString(),
      );
      rethrow;
    }
  }

  Future<VoiceSocketSession> _ensureVoiceSession({
    required String socketUrl,
    required String userId,
  }) async {
    final httpBaseUrl =
        ref.read(imageBaseUrlProvider) ?? httpBaseFromSocketUrl(socketUrl);
    _configureAppLogUploader(httpBaseUrl: httpBaseUrl, userId: userId);
    final existing = _voiceSession;
    if (existing != null) {
      await existing.connect(
        VoiceSocketSessionConfig(
          socketUrl: socketUrl,
          userId: userId,
          clientApp: 'nx_main',
          agentId: 'nx_main',
        ),
      );
      return existing;
    }

    final player = _player ??= NxWavAudioPlayer();
    final session = VoiceSocketSession()
      ..onAudioChunk = (packet) {
        _textIdleTimer?.cancel();
        _receivedPacketsThisTurn++;
        _receivedBytesThisTurn += packet.opus.length;
        if (state.phase == VoiceSocketPhase.waiting) {
          state = state.copyWith(phase: VoiceSocketPhase.responding);
        }
        unawaited(player.addOpusPacket(packet.opus));
      }
      ..onAudioEof = (_) {
        _textIdleTimer?.cancel();
        _uploadAppLog(
          eventName: 'websocket_opus_reception_summary',
          category: 'audio',
          message:
              'nx_main received $_receivedPacketsThisTurn opus packets, $_receivedBytesThisTurn bytes',
          payload: {
            'stream_index': _streamIndex,
            'opus_packets': _receivedPacketsThisTurn,
            'opus_bytes': _receivedBytesThisTurn,
            ..._turnPayload(_lastTurn),
          },
        );
        unawaited(player.flush());
        state = state.copyWith(phase: VoiceSocketPhase.idle);
      }
      ..onTextChunk = (packet) {
        _handleTextPacket(packet.text);
        if (state.phase == VoiceSocketPhase.waiting) {
          state = state.copyWith(phase: VoiceSocketPhase.responding);
        }
        if (!_showOverlayForCurrentTurn) {
          _scheduleTextIdleFallback();
        }
      }
      ..onTextEof = (_) {
        _textIdleTimer?.cancel();
        _showOverlayForCurrentTurn = true;
        state = state.copyWith(phase: VoiceSocketPhase.idle);
      }
      ..onError = (error) {
        state = state.copyWith(
          phase: VoiceSocketPhase.error,
          overlayVisible: true,
          error: error.toString(),
        );
      };

    await session.connect(
      VoiceSocketSessionConfig(
        socketUrl: socketUrl,
        userId: userId,
        clientApp: 'nx_main',
        agentId: 'nx_main',
      ),
    );

    _voiceSession = session;
    return session;
  }

  void _scheduleTextIdleFallback() {
    _textIdleTimer?.cancel();
    _textIdleTimer = Timer(const Duration(milliseconds: 900), () {
      if (state.phase == VoiceSocketPhase.waiting ||
          state.phase == VoiceSocketPhase.responding) {
        _showOverlayForCurrentTurn = true;
        state = state.copyWith(phase: VoiceSocketPhase.idle);
      }
    });
  }

  void _handleTextPacket(String raw) {
    final textFallback = raw;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        _applyRawAssistantText(textFallback);
        return;
      }
      final type = decoded['type'];
      if (type != 'transcript' && type != 'transcript-delta') {
        _applyRawAssistantText(textFallback);
        return;
      }
      final role = decoded['role'];
      final text = decoded['text'];
      final turnkey = decoded['turnkey'];
      if (role is! String || text is! String || text.trim().isEmpty) return;
      if (type == 'transcript-delta') {
        _applyTranscriptDelta(
          role: role,
          text: text,
          turnkey: turnkey is String ? turnkey : null,
          ephemeral: decoded['ephemeral'] == true,
          showOverlay: _showOverlayForCurrentTurn,
        );
      } else {
        _uploadAppLog(
          eventName: 'voice_transcript_text',
          category: 'audio',
          message: text,
          payload: {
            'role': role,
            'text': text,
            'is_delta': false,
            if (turnkey is String) 'turnkey': turnkey,
            ..._turnPayload(_lastTurn),
          },
        );
        _applyTranscript(
          role: role,
          text: text,
          turnkey: turnkey is String ? turnkey : null,
          links: _parseAppLinks(decoded['links']),
          showOverlay: _showOverlayForCurrentTurn,
        );
      }
    } catch (_) {
      _applyRawAssistantText(textFallback);
    }
  }

  void _applyRawAssistantText(String text) {
    if (text.isEmpty) return;
    _applyTranscriptDelta(
      role: 'assistant',
      text: text,
      turnkey: null,
      ephemeral: false,
      showOverlay: _showOverlayForCurrentTurn,
    );
  }

  void _applyTranscript({
    required String role,
    required String text,
    required String? turnkey,
    List<VoiceAppLink> links = const [],
    bool showOverlay = true,
  }) {
    final messages = List<VoiceOverlayMessage>.from(state.messages);
    final replaceIndex = role == 'assistant'
        ? _findMessageIndex(messages, role: role, turnkey: turnkey)
        : -1;
    if (replaceIndex >= 0) {
      messages[replaceIndex] = messages[replaceIndex].copyWith(
        text: text,
        turnkey: turnkey,
        ephemeral: false,
        links: links.isEmpty ? messages[replaceIndex].links : links,
      );
    } else {
      messages.add(
        VoiceOverlayMessage(
          role: role,
          text: text,
          turnkey: turnkey,
          links: links,
        ),
      );
    }
    state = state.copyWith(
      overlayVisible: showOverlay ? true : state.overlayVisible,
      messages: messages,
    );
  }

  void _applyTranscriptDelta({
    required String role,
    required String text,
    required String? turnkey,
    required bool ephemeral,
    bool showOverlay = true,
  }) {
    if (role != 'assistant') return;
    final messages = List<VoiceOverlayMessage>.from(state.messages);
    final index = _findMessageIndex(messages, role: role, turnkey: turnkey);
    if (index >= 0) {
      final existing = messages[index];
      messages[index] = existing.copyWith(
        text: ephemeral || existing.ephemeral ? text : existing.text + text,
        turnkey: turnkey,
        ephemeral: ephemeral,
      );
    } else {
      messages.add(
        VoiceOverlayMessage(
          role: role,
          text: text,
          turnkey: turnkey,
          ephemeral: ephemeral,
        ),
      );
    }
    state = state.copyWith(
      overlayVisible: showOverlay ? true : state.overlayVisible,
      messages: messages,
    );
  }

  int _findMessageIndex(
    List<VoiceOverlayMessage> messages, {
    required String role,
    required String? turnkey,
  }) {
    for (var index = messages.length - 1; index >= 0; index--) {
      final message = messages[index];
      if (message.role != role) continue;
      if (turnkey == null ||
          message.turnkey == null ||
          message.turnkey == turnkey) {
        return index;
      }
    }
    return -1;
  }

  List<VoiceAppLink> _parseAppLinks(Object? raw) {
    if (raw is! List) return const [];
    final links = <VoiceAppLink>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final link = VoiceAppLink.fromJson(item);
      if (link.url.trim().isNotEmpty) {
        links.add(link);
      }
    }
    return links;
  }

  void _configureAppLogUploader({
    required String httpBaseUrl,
    required String userId,
  }) {
    _appLogUploader = NxAppLogUploader(
      httpBaseUrl: httpBaseUrl,
      origin: 'nx_main',
      headers: {
        'X-User-Id': userId,
        if (CfAccess.shouldAttachHeaders(httpBaseUrl)) ...CfAccess.headers,
      },
    );
  }

  void _uploadAppLog({
    required String eventName,
    required String category,
    required String message,
    required Map<String, dynamic> payload,
  }) {
    unawaited(
      _appLogUploader?.upload(
        eventName: eventName,
        category: category,
        message: message,
        payload: {
          'client_app': 'nx_main',
          'agent_id': 'nx_main',
          'agent_name': 'Nx Main Assistant',
          ...payload,
        },
      ),
    );
  }

  Map<String, dynamic> _turnPayload(VoiceSocketTurn? turn) {
    return {
      if (turn != null) ...{
        'turn_id': turn.turn.turnId,
        'nonce': turn.turn.turnRandom,
        'turnkey': turn.turn.turnkey,
        'turn_meta': turn.turn.metaForPacket(0),
      },
    };
  }
}
