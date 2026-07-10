import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:opus_dart/opus_dart.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import 'opus_codec.dart';
import 'pcm_opus_stream_encoder.dart';

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
  StreamSubscription<Uint8List>? _recordingSubscription;
  late final NxPcmOpusStreamEncoder _opusEncoder = NxPcmOpusStreamEncoder(
    sampleRate: sampleRate,
    channels: channels,
    frameTime: frameTime,
  );
  bool _isRecording = false;
  bool _loggedFirstPcmChunk = false;

  bool get isRecording => _isRecording;

  Future<bool> ensurePermission() async {
    if (kIsWeb) {
      debugPrint(
          '[nx_utils voice mic] web platform: microphone permission assumed');
      return true;
    }

    final status = await Permission.microphone.status;
    debugPrint('[nx_utils voice mic] permission_handler status=$status');
    if (status.isGranted) return true;

    // Prefer the record plugin's native microphone permission request. In some
    // iOS builds permission_handler can report permanentlyDenied while AVAudio
    // has already granted recording access.
    final recordPermission = await _recorder.hasPermission();
    debugPrint('[nx_utils voice mic] record hasPermission()=$recordPermission');
    if (recordPermission) return true;

    final result = await Permission.microphone.request();
    debugPrint(
        '[nx_utils voice mic] permission_handler request result=$result');
    return result.isGranted;
  }

  Future<bool> start({
    required FutureOr<void> Function(Uint8List opusPacket) onOpusPacket,
    void Function(Object error)? onError,
  }) async {
    debugPrint(
      '[nx_utils voice mic] start requested sampleRate=$sampleRate '
      'channels=$channels frameTime=$frameTime isRecording=$_isRecording',
    );
    if (_isRecording) return true;
    if (!await ensurePermission()) {
      debugPrint(
          '[nx_utils voice mic] start blocked: microphone permission denied');
      return false;
    }
    await NxOpusCodec.initialize();
    debugPrint('[nx_utils voice mic] opus initialized');

    final config = RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: sampleRate,
      numChannels: channels,
      bitRate: sampleRate * channels * 16,
    );

    try {
      final supported = await _recorder.isEncoderSupported(config.encoder);
      debugPrint(
        '[nx_utils voice mic] encoder=${config.encoder} supported=$supported',
      );
      if (!supported) {
        onError?.call(
            StateError('Recorder encoder ${config.encoder} is not supported'));
        return false;
      }
      final stream = await _recorder.startStream(config);
      _isRecording = true;
      _opusEncoder.reset();
      _loggedFirstPcmChunk = false;
      debugPrint('[nx_utils voice mic] recorder stream started');
      _recordingSubscription = stream.listen(
        (chunk) async {
          try {
            if (!_loggedFirstPcmChunk) {
              _loggedFirstPcmChunk = true;
              debugPrint(
                  '[nx_utils voice mic] received pcm chunk bytes=${chunk.length}');
            }
            for (final packet in await _encodeCompleteFrames(chunk)) {
              await onOpusPacket(packet);
            }
          } catch (error) {
            debugPrint('[nx_utils voice mic] encode/send error: $error');
            onError?.call(error);
          }
        },
        onError: (Object error) {
          debugPrint('[nx_utils voice mic] stream error: $error');
          onError?.call(error);
        },
      );
      return true;
    } catch (error) {
      debugPrint('[nx_utils voice mic] startStream error: $error');
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

    if (!flushRemainder) {
      _opusEncoder.reset();
      return const [];
    }

    return _opusEncoder.flush(padFinalFrame: true);
  }

  Future<void> dispose() async {
    await stop(flushRemainder: false);
    await _recorder.dispose();
  }

  Future<List<Uint8List>> _encodeCompleteFrames(Uint8List chunk) async {
    return _opusEncoder.addPcmChunk(chunk);
  }
}
