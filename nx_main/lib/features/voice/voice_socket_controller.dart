import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  NxVoiceSocketClient? _socket;
  NxMicrophoneOpusStreamer? _mic;
  NxWavAudioPlayer? _player;
  NxAppLogUploader? _appLogUploader;
  String? _sessionKey;
  int _streamIndex = 0;
  int _packetIndex = 0;
  int _sentPacketsThisTurn = 0;
  int _sentBytesThisTurn = 0;
  int _receivedPacketsThisTurn = 0;
  int _receivedBytesThisTurn = 0;
  NxVoiceAudioTurn? _activeTurn;
  NxVoiceAudioTurn? _lastTurn;
  bool _stopInFlight = false;

  @override
  VoiceSocketState build() {
    ref.onDispose(() {
      unawaited(_mic?.dispose());
      unawaited(_player?.dispose());
      unawaited(_socket?.disconnect());
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
      final socket = await _ensureSocket(socketUrl: socketUrl, userId: userId);
      final mic = _mic ??= NxMicrophoneOpusStreamer();
      _streamIndex++;
      _packetIndex = 0;
      _sentPacketsThisTurn = 0;
      _sentBytesThisTurn = 0;
      _receivedPacketsThisTurn = 0;
      _receivedBytesThisTurn = 0;
      _activeTurn = NxVoiceAudioTurn.create(streamIndex: _streamIndex);
      _lastTurn = _activeTurn;
      _stopInFlight = false;

      final started = await mic.start(
        onOpusPacket: (opus) {
          _sentPacketsThisTurn++;
          _sentBytesThisTurn += opus.length;
          socket.sendAudioChunk(
            opus,
            streamIndex: _streamIndex,
            packetIndex: _packetIndex,
            meta: _activeTurn?.metaForPacket(_packetIndex),
          );
          _packetIndex++;
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
      final socket = _socket;
      final mic = _mic;
      final turn = _activeTurn;
      if (socket == null || mic == null) {
        state = state.copyWith(phase: VoiceSocketPhase.idle);
        return;
      }

      final remaining = await mic.stop();
      for (final opus in remaining) {
        _sentPacketsThisTurn++;
        _sentBytesThisTurn += opus.length;
        socket.sendAudioChunk(
          opus,
          streamIndex: _streamIndex,
          packetIndex: _packetIndex,
          meta: turn?.metaForPacket(_packetIndex),
        );
        _packetIndex++;
      }
      socket.sendAudioEof(
        streamIndex: _streamIndex,
        meta: turn?.metaForPacket(_packetIndex),
      );
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

  Future<NxVoiceSocketClient> _ensureSocket({
    required String socketUrl,
    required String userId,
  }) async {
    final key = '$socketUrl|$userId';
    final httpBaseUrl =
        ref.read(imageBaseUrlProvider) ?? httpBaseFromSocketUrl(socketUrl);
    final existing = _socket;
    if (existing != null && existing.isConnected && _sessionKey == key) {
      _configureAppLogUploader(httpBaseUrl: httpBaseUrl, userId: userId);
      return existing;
    }

    await existing?.disconnect();
    _configureAppLogUploader(httpBaseUrl: httpBaseUrl, userId: userId);
    final player = _player ??= NxWavAudioPlayer();
    final socket = NxVoiceSocketClient()
      ..onAudioChunk = (packet) {
        _receivedPacketsThisTurn++;
        _receivedBytesThisTurn += packet.opus.length;
        if (state.phase == VoiceSocketPhase.waiting) {
          state = state.copyWith(phase: VoiceSocketPhase.responding);
        }
        unawaited(player.addOpusPacket(packet.opus));
      }
      ..onAudioEof = (_) {
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
      }
      ..onTextEof = (_) {
        state = state.copyWith(phase: VoiceSocketPhase.idle);
      }
      ..onError = (error) {
        state = state.copyWith(
          phase: VoiceSocketPhase.error,
          overlayVisible: true,
          error: error.toString(),
        );
      };

    final headers = <String, String>{
      'X-User-Id': userId,
      'X-Client-App': 'nx_main',
      'X-Agent-Id': 'nx_main',
      if (CfAccess.shouldAttachHeaders(socketUrl)) ...CfAccess.headers,
    };
    final connected = await socket.connect(socketUrl, headers: headers);
    if (!connected) {
      throw StateError('Could not connect to voice socket.');
    }

    _socket = socket;
    _sessionKey = key;
    return socket;
  }

  void _handleTextPacket(String raw) {
    final textFallback = raw.trim();
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
        );
      }
    } catch (_) {
      _applyRawAssistantText(textFallback);
    }
  }

  void _applyRawAssistantText(String text) {
    if (text.isEmpty) return;
    _applyTranscript(role: 'assistant', text: text, turnkey: null);
  }

  void _applyTranscript({
    required String role,
    required String text,
    required String? turnkey,
    List<VoiceAppLink> links = const [],
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
    state = state.copyWith(overlayVisible: true, messages: messages);
  }

  void _applyTranscriptDelta({
    required String role,
    required String text,
    required String? turnkey,
    required bool ephemeral,
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
    state = state.copyWith(overlayVisible: true, messages: messages);
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

  Map<String, dynamic> _turnPayload(NxVoiceAudioTurn? turn) {
    return {
      if (turn != null) ...{
        'turn_id': turn.turnId,
        'nonce': turn.turnRandom,
        'turnkey': turn.turnkey,
        'turn_meta': turn.metaForPacket(0),
      },
    };
  }
}
