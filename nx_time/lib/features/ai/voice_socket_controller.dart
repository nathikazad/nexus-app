import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
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

class VoiceTranscriptMessage {
  const VoiceTranscriptMessage({
    required this.role,
    required this.text,
    this.turnkey,
    this.ephemeral = false,
  });

  final String role;
  final String text;
  final String? turnkey;
  final bool ephemeral;

  bool get fromUser => role == 'user';

  VoiceTranscriptMessage copyWith({
    String? text,
    String? turnkey,
    bool? ephemeral,
  }) {
    return VoiceTranscriptMessage(
      role: role,
      text: text ?? this.text,
      turnkey: turnkey ?? this.turnkey,
      ephemeral: ephemeral ?? this.ephemeral,
    );
  }
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
  final List<VoiceTranscriptMessage> messages;

  bool get active => switch (phase) {
    VoiceSocketPhase.connecting ||
    VoiceSocketPhase.recording ||
    VoiceSocketPhase.waiting ||
    VoiceSocketPhase.responding => true,
    VoiceSocketPhase.idle || VoiceSocketPhase.error => false,
  };

  VoiceSocketState copyWith({
    VoiceSocketPhase? phase,
    String? error,
    bool clearError = false,
    bool? overlayVisible,
    List<VoiceTranscriptMessage>? messages,
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
  String? _sessionKey;
  int _streamIndex = 0;
  int _packetIndex = 0;
  int _sentPacketsThisTurn = 0;
  int _sentBytesThisTurn = 0;
  int _receivedPacketsThisTurn = 0;
  int _receivedBytesThisTurn = 0;
  NxVoiceAudioTurn? _activeTurn;
  NxVoiceAudioTurn? _lastTurn;
  NxAppLogUploader? _appLogUploader;
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
          'client_app': 'nx_time',
          'agent_id': 'nx_time',
          'agent_name': 'Nx Time Assistant',
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

  void _applyTranscript({
    required String role,
    required String text,
    required String? turnkey,
  }) {
    final messages = List<VoiceTranscriptMessage>.from(state.messages);
    final replaceIndex = role == 'assistant'
        ? _findMessageIndex(messages, role: role, turnkey: turnkey)
        : -1;
    if (replaceIndex >= 0) {
      messages[replaceIndex] = messages[replaceIndex].copyWith(
        text: text,
        turnkey: turnkey,
        ephemeral: false,
      );
    } else {
      messages.add(
        VoiceTranscriptMessage(role: role, text: text, turnkey: turnkey),
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
    final messages = List<VoiceTranscriptMessage>.from(state.messages);
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
        VoiceTranscriptMessage(
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
    List<VoiceTranscriptMessage> messages, {
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

  void dismissOverlay() {
    state = state.copyWith(overlayVisible: false, clearError: true);
  }

  Future<void> startRecording() async {
    debugPrint('[nx_time voice] startRecording requested phase=${state.phase}');
    if (state.phase == VoiceSocketPhase.recording ||
        state.phase == VoiceSocketPhase.connecting) {
      debugPrint('[nx_time voice] start ignored: already active');
      return;
    }

    final userId = ref.read(userIdProvider);
    final socketUrl = ref.read(sockWsUrlProvider);
    debugPrint(
      '[nx_time voice] auth snapshot userId=$userId socketUrl=$socketUrl',
    );
    if (userId == null || userId.isEmpty || socketUrl == null) {
      debugPrint('[nx_time voice] start failed: missing auth/socket URL');
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
      debugPrint(
        '[nx_time voice] starting mic stream streamIndex=$_streamIndex '
        'turnkey=${_activeTurn!.turnkey}',
      );

      final started = await mic.start(
        onOpusPacket: (opus) {
          if (_sentPacketsThisTurn == 0) {
            debugPrint(
              '[nx_time voice] first opus packet bytes=${opus.length}',
            );
          }
          _sentPacketsThisTurn++;
          _sentBytesThisTurn += opus.length;
          socket.sendAudioChunk(
            opus,
            streamIndex: _streamIndex,
            packetIndex: _packetIndex,
            meta: _activeTurn?.metaForPacket(_packetIndex),
          );
          _packetIndex++;
          if (_sentPacketsThisTurn % 25 == 0) {
            debugPrint(
              '[nx_time voice] sent $_sentPacketsThisTurn opus packets '
              'latestBytes=${opus.length}',
            );
          }
        },
        onError: (error) {
          debugPrint('[nx_time voice] mic error: $error');
          state = state.copyWith(
            phase: VoiceSocketPhase.error,
            overlayVisible: true,
            error: error.toString(),
          );
        },
      );

      if (!started) {
        debugPrint('[nx_time voice] mic did not start');
        _activeTurn = null;
        state = state.copyWith(
          phase: VoiceSocketPhase.error,
          overlayVisible: true,
          error: 'Could not start microphone recording.',
        );
        return;
      }
      debugPrint('[nx_time voice] recording started');
      _uploadAppLog(
        eventName: 'mic_record_start',
        category: 'audio',
        message: 'nx_time mic recording started',
        payload: {'stream_index': _streamIndex, ..._turnPayload(_activeTurn)},
      );
      state = state.copyWith(
        phase: VoiceSocketPhase.recording,
        overlayVisible: true,
        clearError: true,
      );
    } catch (error) {
      debugPrint('[nx_time voice] start error: $error');
      _activeTurn = null;
      state = state.copyWith(
        phase: VoiceSocketPhase.error,
        overlayVisible: true,
        error: error.toString(),
      );
    }
  }

  Future<void> stopRecording() async {
    debugPrint('[nx_time voice] stopRecording requested phase=${state.phase}');
    if (_stopInFlight || state.phase != VoiceSocketPhase.recording) {
      debugPrint(
        '[nx_time voice] stop ignored stopInFlight=$_stopInFlight '
        'phase=${state.phase}',
      );
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
        debugPrint('[nx_time voice] stop found no socket/mic');
        state = state.copyWith(phase: VoiceSocketPhase.idle);
        return;
      }

      final remaining = await mic.stop();
      debugPrint(
        '[nx_time voice] mic stopped; remaining=${remaining.length} '
        'sent=$_sentPacketsThisTurn streamIndex=$_streamIndex',
      );
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
      debugPrint(
        '[nx_time voice] sent audio EOF streamIndex=$_streamIndex '
        'totalPackets=$_sentPacketsThisTurn turnkey=${turn?.turnkey}',
      );
      _uploadAppLog(
        eventName: 'socket_audio_sent_summary',
        category: 'audio',
        message:
            'nx_time sent $_sentPacketsThisTurn opus packets, $_sentBytesThisTurn bytes',
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
        message: 'nx_time mic recording stopped',
        payload: {
          'stream_index': _streamIndex,
          'opus_packets': _sentPacketsThisTurn,
          'opus_bytes': _sentBytesThisTurn,
          ..._turnPayload(turn),
        },
      );
    } catch (error) {
      debugPrint('[nx_time voice] stop error: $error');
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
      debugPrint('[nx_time voice] reusing socket session $key');
      _appLogUploader ??= NxAppLogUploader(
        httpBaseUrl: httpBaseUrl,
        origin: 'nx_time',
        headers: {
          'X-User-Id': userId,
          if (CfAccess.shouldAttachHeaders(httpBaseUrl)) ...CfAccess.headers,
        },
      );
      return existing;
    }

    final parsedSocketUri = Uri.tryParse(socketUrl);
    debugPrint('[nx_time voice] connecting socket session=$key');
    debugPrint(
      '[nx_time voice] socket endpoint raw=$socketUrl '
      'scheme=${parsedSocketUri?.scheme ?? '<invalid>'} '
      'host=${parsedSocketUri?.host ?? '<invalid>'} '
      'port=${parsedSocketUri?.hasPort == true ? parsedSocketUri!.port : '<default>'}',
    );
    await existing?.disconnect();
    _appLogUploader = NxAppLogUploader(
      httpBaseUrl: httpBaseUrl,
      origin: 'nx_time',
      headers: {
        'X-User-Id': userId,
        if (CfAccess.shouldAttachHeaders(httpBaseUrl)) ...CfAccess.headers,
      },
    );
    final player = _player ??= NxWavAudioPlayer();
    final socket = NxVoiceSocketClient()
      ..onAudioChunk = (packet) {
        _receivedPacketsThisTurn++;
        _receivedBytesThisTurn += packet.opus.length;
        debugPrint(
          '[nx_time voice] received audio packet '
          'bytes=${packet.opus.length} stream=${packet.streamIndex} '
          'packet=${packet.packetIndex}',
        );
        if (state.phase == VoiceSocketPhase.waiting) {
          state = state.copyWith(phase: VoiceSocketPhase.responding);
        }
        unawaited(player.addOpusPacket(packet.opus));
      }
      ..onAudioEof = (_) {
        debugPrint('[nx_time voice] received audio EOF');
        _uploadAppLog(
          eventName: 'websocket_opus_reception_summary',
          category: 'audio',
          message:
              'nx_time received $_receivedPacketsThisTurn opus packets, $_receivedBytesThisTurn bytes',
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
        try {
          final decoded = jsonDecode(packet.text);
          if (decoded is Map<String, dynamic> &&
              (decoded['type'] == 'transcript' ||
                  decoded['type'] == 'transcript-delta')) {
            final role = decoded['role'];
            final text = decoded['text'];
            final turnkey = decoded['turnkey'];
            final isDelta = decoded['type'] == 'transcript-delta';
            final ephemeral = decoded['ephemeral'] == true;
            debugPrint(
              '[nx_time voice] ${isDelta ? 'transcript-delta' : 'transcript'} '
              '$role turnkey=$turnkey ephemeral=$ephemeral: $text',
            );
            if (role is String && text is String && text.trim().isNotEmpty) {
              _uploadAppLog(
                eventName: isDelta
                    ? 'voice_transcript_delta'
                    : 'voice_transcript_text',
                category: 'audio',
                message: text,
                payload: {
                  'role': role,
                  'text': text,
                  'is_delta': isDelta,
                  if (isDelta) 'ephemeral': ephemeral,
                  if (turnkey is String) 'turnkey': turnkey,
                  ..._turnPayload(_lastTurn),
                },
              );
              if (isDelta) {
                _applyTranscriptDelta(
                  role: role,
                  text: text,
                  turnkey: turnkey is String ? turnkey : null,
                  ephemeral: ephemeral,
                );
              } else {
                _applyTranscript(
                  role: role,
                  text: text,
                  turnkey: turnkey is String ? turnkey : null,
                );
              }
            }
          } else {
            debugPrint('[nx_time voice] text: ${packet.text}');
          }
        } catch (_) {
          debugPrint('[nx_time voice] text: ${packet.text}');
        }
        if (state.phase == VoiceSocketPhase.waiting) {
          state = state.copyWith(phase: VoiceSocketPhase.responding);
        }
      }
      ..onTextEof = (_) {
        debugPrint('[nx_time voice] received text EOF');
        state = state.copyWith(phase: VoiceSocketPhase.idle);
      }
      ..onError = (error) {
        debugPrint('[nx_time voice] socket error: $error');
        state = state.copyWith(
          phase: VoiceSocketPhase.error,
          overlayVisible: true,
          error: error.toString(),
        );
      };

    final headers = <String, String>{
      'X-User-Id': userId,
      'X-Client-App': 'nx_time',
      'X-Agent-Id': 'nx_time',
      if (CfAccess.shouldAttachHeaders(socketUrl)) ...CfAccess.headers,
    };
    debugPrint(
      '[nx_time voice] socket headers client_app=nx_time '
      'agent_id=nx_time cf=${CfAccess.shouldAttachHeaders(socketUrl)}',
    );
    final connected = await socket.connect(socketUrl, headers: headers);
    if (!connected) {
      throw StateError('Could not connect to voice socket.');
    }

    _socket = socket;
    _sessionKey = key;
    debugPrint('[nx_time voice] socket connected');
    return socket;
  }
}
