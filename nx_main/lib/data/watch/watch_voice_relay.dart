import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:nexus_voice_assistant/data/voice/voice_socket_session.dart';
import 'package:nexus_voice_assistant/data/watch/watch_bridge_service.dart';
import 'package:nx_utils/nx_utils.dart';

class WatchVoiceRelay {
  WatchVoiceRelay({
    required WatchBridgeGateway bridge,
    VoiceSocketSessionPort? socketSession,
    NxPcmOpusStreamEncoder? inputEncoder,
    Future<Uint8List> Function(Uint8List opus)? decodeResponseOpus,
  })  : _bridge = bridge,
        _socketSession = socketSession ?? VoiceSocketSession(),
        _inputEncoder = inputEncoder ??
            NxPcmOpusStreamEncoder(
              sampleRate: socketSampleRate,
              channels: channels,
            ),
        _decodeResponseOpus = decodeResponseOpus {
    _socketSession
      ..onAudioChunk = _handleResponseAudio
      ..onAudioEof = _handleResponseEof
      ..onTextChunk = _handleResponseText
      ..onTextEof = (_) {
        unawaited(_sendStatus('Connected'));
      }
      ..onError = _handleSocketError;
  }

  static const int watchSampleRate = 24000;
  static const int socketSampleRate = 16000;
  static const int channels = 1;

  final WatchBridgeGateway _bridge;
  final VoiceSocketSessionPort _socketSession;
  final NxPcmOpusStreamEncoder _inputEncoder;
  final Future<Uint8List> Function(Uint8List opus)? _decodeResponseOpus;

  final NxPcm16MonoResampler _watchToSocketResampler = NxPcm16MonoResampler(
      inputSampleRate: watchSampleRate, outputSampleRate: socketSampleRate);
  final NxOpusPcmStreamDecoder _responseDecoder = NxOpusPcmStreamDecoder(
    sampleRate: socketSampleRate,
    channels: channels,
  );
  final NxPcm16MonoResampler _socketToWatchResampler = NxPcm16MonoResampler(
      inputSampleRate: socketSampleRate, outputSampleRate: watchSampleRate);

  StreamSubscription<WatchAudioStart>? _audioStartSubscription;
  StreamSubscription<WatchAudioPacket>? _audioSubscription;
  StreamSubscription<WatchAudioEOF>? _eofSubscription;

  String? _socketUrl;
  String? _userId;
  bool _started = false;
  bool _inputTurnActive = false;
  Future<void> _sendChain = Future<void>.value();
  Future<void> _playbackChain = Future<void>.value();

  void configure({
    required String? socketUrl,
    required String? userId,
  }) {
    final changed = _socketUrl != socketUrl || _userId != userId;
    _socketUrl = socketUrl;
    _userId = userId;
    if (changed && _socketSession.isConnected) {
      unawaited(_socketSession.disconnect());
    }
  }

  void start() {
    if (_started) return;
    _started = true;
    _audioStartSubscription =
        _bridge.audioStartStream.listen(_handleAudioStart);
    _audioSubscription = _bridge.audioStream.listen(_handleAudioPacket);
    _eofSubscription = _bridge.eofStream.listen(_handleAudioEof);
  }

  Future<void> stop() async {
    await _audioStartSubscription?.cancel();
    await _audioSubscription?.cancel();
    await _eofSubscription?.cancel();
    _audioStartSubscription = null;
    _audioSubscription = null;
    _eofSubscription = null;
    _started = false;
    _resetTurnState();
    await _socketSession.disconnect();
  }

  Future<void> dispose() async {
    await stop();
    _responseDecoder.dispose();
  }

  Future<void> waitForIdle() async {
    await _sendChain;
    await _playbackChain;
  }

  void _handleAudioStart(WatchAudioStart _) {
    _resetTurnState();
    _inputTurnActive = true;
    _queueSend(() async {
      await _sendStatus('Connecting...');

      final socketUrl = _socketUrl;
      final userId = _userId;
      if (socketUrl == null ||
          socketUrl.trim().isEmpty ||
          userId == null ||
          userId.trim().isEmpty) {
        throw StateError('Not logged in or missing socket URL.');
      }

      await _socketSession.connect(
        VoiceSocketSessionConfig(
          socketUrl: socketUrl,
          userId: userId,
          clientApp: 'nx_watch',
          agentId: 'nx_watch',
        ),
      );
      _socketSession.beginAudioTurn();
      await _sendStatus('Recording...');
    });
  }

  void _handleAudioPacket(WatchAudioPacket packet) {
    if (!_inputTurnActive) {
      _handleAudioStart(WatchAudioStart());
    }

    _queueSend(() async {
      final pcm16 = _resampleWatchPacket(packet);
      final opusPackets = await _inputEncoder.addPcmChunk(pcm16);
      for (final opus in opusPackets) {
        _socketSession.sendAudioPacket(opus);
      }
    });
  }

  void _handleAudioEof(WatchAudioEOF _) {
    _queueSend(() async {
      if (!_inputTurnActive) return;
      final tailPcm16 = _watchToSocketResampler.flush();
      if (tailPcm16.isNotEmpty) {
        final tailPackets = await _inputEncoder.addPcmChunk(tailPcm16);
        for (final opus in tailPackets) {
          _socketSession.sendAudioPacket(opus);
        }
      }
      final finalPackets = await _inputEncoder.flush(padFinalFrame: true);
      for (final opus in finalPackets) {
        _socketSession.sendAudioPacket(opus);
      }
      _socketSession.endAudioTurn();
      _inputTurnActive = false;
      await _sendStatus('Waiting...');
    });
  }

  void _handleResponseAudio(NxVoiceAudioChunk packet) {
    _playbackChain = _playbackChain.then((_) async {
      final decode = _decodeResponseOpus;
      final pcm16 = decode == null
          ? await _responseDecoder.decode(packet.opus)
          : await decode(packet.opus);
      final pcm24 = _socketToWatchResampler.process(pcm16);
      if (pcm24.isNotEmpty) {
        await _bridge.sendPlaybackAudioToWatch(
          pcm24,
          sampleRate: watchSampleRate,
        );
      }
    }).catchError((Object error, StackTrace stackTrace) {
      _handleSocketError(error);
    });
  }

  void _handleResponseEof(NxVoiceAudioEof _) {
    _playbackChain = _playbackChain.then((_) async {
      final tail = _socketToWatchResampler.flush();
      if (tail.isNotEmpty) {
        await _bridge.sendPlaybackAudioToWatch(
          tail,
          sampleRate: watchSampleRate,
        );
      }
      _responseDecoder.reset();
      await _bridge.sendPlaybackEofToWatch();
      await _sendStatus('Connected');
    }).catchError((Object error, StackTrace stackTrace) {
      _handleSocketError(error);
    });
  }

  void _handleResponseText(NxVoiceTextChunk packet) {
    final update = _assistantTextFromPacket(packet.text);
    if (update == null || update.text.isEmpty) return;
    unawaited(
      _bridge.sendTextUpdateToWatch(
        update.text,
        replace: update.replace,
      ),
    );
  }

  Uint8List _resampleWatchPacket(WatchAudioPacket packet) {
    if (packet.sampleRate == socketSampleRate) {
      return packet.data;
    }
    if (packet.sampleRate != watchSampleRate) {
      throw StateError('Unsupported watch sample rate: ${packet.sampleRate}');
    }
    return _watchToSocketResampler.process(packet.data);
  }

  void _queueSend(Future<void> Function() action) {
    _sendChain = _sendChain.then((_) => action()).catchError(
      (Object error, StackTrace stackTrace) {
        _inputTurnActive = false;
        _handleSocketError(error);
      },
    );
  }

  Future<void> _sendStatus(String status) {
    return _bridge.sendStatusToWatch(status).then((_) {});
  }

  void _handleSocketError(Object error) {
    unawaited(_bridge.sendErrorToWatch(error.toString()));
  }

  _WatchTextUpdate? _assistantTextFromPacket(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return _WatchTextUpdate.append(raw);
      }
      final type = decoded['type'];
      if (type != 'transcript' && type != 'transcript-delta') {
        return _WatchTextUpdate.append(raw);
      }
      if (decoded['role'] != 'assistant') return null;
      final text = decoded['text'];
      if (text is! String) return null;
      return _WatchTextUpdate(
        text: text,
        replace: type == 'transcript' || decoded['ephemeral'] == true,
      );
    } catch (_) {
      return _WatchTextUpdate.append(raw);
    }
  }

  void _resetTurnState() {
    _watchToSocketResampler.reset();
    _socketToWatchResampler.reset();
    _inputEncoder.reset();
    _responseDecoder.reset();
  }
}

class _WatchTextUpdate {
  const _WatchTextUpdate({
    required this.text,
    required this.replace,
  });

  factory _WatchTextUpdate.append(String text) {
    return _WatchTextUpdate(text: text, replace: false);
  }

  final String text;
  final bool replace;
}
