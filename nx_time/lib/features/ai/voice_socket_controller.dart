import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_voice/nx_voice.dart';

enum VoiceSocketPhase {
  idle,
  connecting,
  recording,
  waiting,
  responding,
  error,
}

class VoiceSocketState {
  const VoiceSocketState({required this.phase, this.error});

  const VoiceSocketState.idle() : this(phase: VoiceSocketPhase.idle);

  final VoiceSocketPhase phase;
  final String? error;

  bool get active => switch (phase) {
    VoiceSocketPhase.connecting ||
    VoiceSocketPhase.recording ||
    VoiceSocketPhase.waiting ||
    VoiceSocketPhase.responding => true,
    VoiceSocketPhase.idle || VoiceSocketPhase.error => false,
  };
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
        error: 'Not logged in or missing socket URL.',
      );
      return;
    }

    state = const VoiceSocketState(phase: VoiceSocketPhase.connecting);
    try {
      final socket = await _ensureSocket(socketUrl: socketUrl, userId: userId);
      final mic = _mic ??= NxMicrophoneOpusStreamer();
      _streamIndex++;
      _packetIndex = 0;
      _sentPacketsThisTurn = 0;
      _stopInFlight = false;
      debugPrint(
        '[nx_time voice] starting mic stream streamIndex=$_streamIndex',
      );

      final started = await mic.start(
        onOpusPacket: (opus) {
          if (_sentPacketsThisTurn == 0) {
            debugPrint(
              '[nx_time voice] first opus packet bytes=${opus.length}',
            );
          }
          _sentPacketsThisTurn++;
          socket.sendAudioChunk(
            opus,
            streamIndex: _streamIndex,
            packetIndex: _packetIndex++,
          );
          if (_sentPacketsThisTurn % 25 == 0) {
            debugPrint(
              '[nx_time voice] sent $_sentPacketsThisTurn opus packets '
              'latestBytes=${opus.length}',
            );
          }
        },
        onError: (error) {
          debugPrint('[nx_time voice] mic error: $error');
          state = VoiceSocketState(
            phase: VoiceSocketPhase.error,
            error: error.toString(),
          );
        },
      );

      if (!started) {
        debugPrint('[nx_time voice] mic did not start');
        state = const VoiceSocketState(
          phase: VoiceSocketPhase.error,
          error: 'Could not start microphone recording.',
        );
        return;
      }
      debugPrint('[nx_time voice] recording started');
      state = const VoiceSocketState(phase: VoiceSocketPhase.recording);
    } catch (error) {
      debugPrint('[nx_time voice] start error: $error');
      state = VoiceSocketState(
        phase: VoiceSocketPhase.error,
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
    state = const VoiceSocketState(phase: VoiceSocketPhase.waiting);

    try {
      final socket = _socket;
      final mic = _mic;
      if (socket == null || mic == null) {
        debugPrint('[nx_time voice] stop found no socket/mic');
        state = const VoiceSocketState.idle();
        return;
      }

      final remaining = await mic.stop();
      debugPrint(
        '[nx_time voice] mic stopped; remaining=${remaining.length} '
        'sent=$_sentPacketsThisTurn streamIndex=$_streamIndex',
      );
      for (final opus in remaining) {
        _sentPacketsThisTurn++;
        socket.sendAudioChunk(
          opus,
          streamIndex: _streamIndex,
          packetIndex: _packetIndex++,
        );
      }
      socket.sendAudioEof(streamIndex: _streamIndex);
      debugPrint(
        '[nx_time voice] sent audio EOF streamIndex=$_streamIndex '
        'totalPackets=$_sentPacketsThisTurn',
      );
    } catch (error) {
      debugPrint('[nx_time voice] stop error: $error');
      state = VoiceSocketState(
        phase: VoiceSocketPhase.error,
        error: error.toString(),
      );
    } finally {
      _stopInFlight = false;
    }
  }

  Future<NxVoiceSocketClient> _ensureSocket({
    required String socketUrl,
    required String userId,
  }) async {
    final key = '$socketUrl|$userId';
    final existing = _socket;
    if (existing != null && existing.isConnected && _sessionKey == key) {
      debugPrint('[nx_time voice] reusing socket session $key');
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
    final player = _player ??= NxWavAudioPlayer();
    final socket = NxVoiceSocketClient()
      ..onAudioChunk = (packet) {
        debugPrint(
          '[nx_time voice] received audio packet '
          'bytes=${packet.opus.length} stream=${packet.streamIndex} '
          'packet=${packet.packetIndex}',
        );
        if (state.phase == VoiceSocketPhase.waiting) {
          state = const VoiceSocketState(phase: VoiceSocketPhase.responding);
        }
        unawaited(player.addOpusPacket(packet.opus));
      }
      ..onAudioEof = (_) {
        debugPrint('[nx_time voice] received audio EOF');
        unawaited(player.flush());
        state = const VoiceSocketState.idle();
      }
      ..onTextChunk = (packet) {
        debugPrint('[nx_time voice] text: ${packet.text}');
        if (state.phase == VoiceSocketPhase.waiting) {
          state = const VoiceSocketState(phase: VoiceSocketPhase.responding);
        }
      }
      ..onTextEof = (_) {
        debugPrint('[nx_time voice] received text EOF');
        state = const VoiceSocketState.idle();
      }
      ..onError = (error) {
        debugPrint('[nx_time voice] socket error: $error');
        state = VoiceSocketState(
          phase: VoiceSocketPhase.error,
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
