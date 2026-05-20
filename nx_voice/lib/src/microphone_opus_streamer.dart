import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:opus_dart/opus_dart.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import 'opus_codec.dart';

class NxMicrophoneOpusStreamer {
  NxMicrophoneOpusStreamer({
    this.sampleRate = 16000,
    this.channels = 1,
    this.frameTime = FrameTime.ms60,
  });

  final int sampleRate;
  final int channels;
  final FrameTime frameTime;

  final AudioRecorder _recorder = AudioRecorder();
  final List<Uint8List> _pendingPcm = [];
  StreamSubscription<Uint8List>? _recordingSubscription;
  bool _isRecording = false;
  bool _loggedFirstPcmChunk = false;

  bool get isRecording => _isRecording;

  Future<bool> ensurePermission() async {
    if (kIsWeb) {
      debugPrint('[nx_voice mic] web platform: microphone permission assumed');
      return true;
    }

    final existingRecordPermission =
        await _recorder.hasPermission(request: false);
    debugPrint(
      '[nx_voice mic] record hasPermission(request:false)='
      '$existingRecordPermission',
    );
    if (existingRecordPermission) {
      return true;
    }

    final status = await Permission.microphone.status;
    debugPrint('[nx_voice mic] permission_handler status=$status');
    if (status.isGranted) return true;

    // Prefer the record plugin's native microphone permission request. In some
    // iOS builds permission_handler can report permanentlyDenied while AVAudio
    // has already granted recording access.
    final recordPermission = await _recorder.hasPermission();
    debugPrint('[nx_voice mic] record hasPermission()=$recordPermission');
    if (recordPermission) return true;

    final result = await Permission.microphone.request();
    debugPrint('[nx_voice mic] permission_handler request result=$result');
    return result.isGranted;
  }

  Future<bool> start({
    required FutureOr<void> Function(Uint8List opusPacket) onOpusPacket,
    void Function(Object error)? onError,
  }) async {
    debugPrint(
      '[nx_voice mic] start requested sampleRate=$sampleRate '
      'channels=$channels frameTime=$frameTime isRecording=$_isRecording',
    );
    if (_isRecording) return true;
    if (!await ensurePermission()) {
      debugPrint('[nx_voice mic] start blocked: microphone permission denied');
      return false;
    }
    await NxOpusCodec.initialize();
    debugPrint('[nx_voice mic] opus initialized');

    final config = RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: sampleRate,
      numChannels: channels,
      bitRate: sampleRate * channels * 16,
    );

    try {
      final supported = await _recorder.isEncoderSupported(config.encoder);
      debugPrint(
        '[nx_voice mic] encoder=${config.encoder} supported=$supported',
      );
      if (!supported) {
        onError?.call(
            StateError('Recorder encoder ${config.encoder} is not supported'));
        return false;
      }
      final stream = await _recorder.startStream(config);
      _isRecording = true;
      _pendingPcm.clear();
      _loggedFirstPcmChunk = false;
      debugPrint('[nx_voice mic] recorder stream started');
      _recordingSubscription = stream.listen(
        (chunk) async {
          try {
            if (!_loggedFirstPcmChunk) {
              _loggedFirstPcmChunk = true;
              debugPrint(
                  '[nx_voice mic] received pcm chunk bytes=${chunk.length}');
            }
            for (final packet in await _encodeCompleteFrames(chunk)) {
              await onOpusPacket(packet);
            }
          } catch (error) {
            debugPrint('[nx_voice mic] encode/send error: $error');
            onError?.call(error);
          }
        },
        onError: (Object error) {
          debugPrint('[nx_voice mic] stream error: $error');
          onError?.call(error);
        },
      );
      return true;
    } catch (error) {
      debugPrint('[nx_voice mic] startStream error: $error');
      onError?.call(error);
      return false;
    }
  }

  Future<List<Uint8List>> stop({
    bool flushRemainder = true,
  }) async {
    if (!_isRecording) return const [];
    await _recordingSubscription?.cancel();
    _recordingSubscription = null;
    await _recorder.stop();
    _isRecording = false;

    if (!flushRemainder || _pendingPcm.isEmpty) {
      _pendingPcm.clear();
      return const [];
    }

    final remainder = _drainPending();
    return NxOpusCodec.encodePcm16(
      remainder,
      sampleRate: sampleRate,
      channels: channels,
      frameTime: frameTime,
      fillUpLastFrame: true,
    );
  }

  Future<void> dispose() async {
    await stop(flushRemainder: false);
    await _recorder.dispose();
  }

  Future<List<Uint8List>> _encodeCompleteFrames(Uint8List chunk) async {
    _pendingPcm.add(chunk);
    final combined = _drainPending();
    final frameSize = _frameSizeBytes();
    if (combined.length < frameSize) {
      _pendingPcm.add(combined);
      return const [];
    }

    final completeLength = combined.length - (combined.length % frameSize);
    final complete = Uint8List.sublistView(combined, 0, completeLength);
    if (completeLength < combined.length) {
      _pendingPcm.add(Uint8List.sublistView(combined, completeLength));
    }

    return NxOpusCodec.encodePcm16(
      complete,
      sampleRate: sampleRate,
      channels: channels,
      frameTime: frameTime,
      fillUpLastFrame: false,
    );
  }

  Uint8List _drainPending() {
    final total = _pendingPcm.fold<int>(0, (sum, chunk) => sum + chunk.length);
    final combined = Uint8List(total);
    var offset = 0;
    for (final chunk in _pendingPcm) {
      combined.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }
    _pendingPcm.clear();
    return combined;
  }

  int _frameSizeBytes() {
    final millis = switch (frameTime) {
      FrameTime.ms2_5 => 2.5,
      FrameTime.ms5 => 5.0,
      FrameTime.ms10 => 10.0,
      FrameTime.ms20 => 20.0,
      FrameTime.ms40 => 40.0,
      FrameTime.ms60 => 60.0,
    };
    return (sampleRate * (millis / 1000) * channels * 2).round();
  }
}
