import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final AudioRecorder _recorder = AudioRecorder();
  StreamController<Uint8List>? _audioStreamController;
  bool _isRecording = false;
  bool _isInitialized = false;

  Stream<Uint8List>? get audioStream => _audioStreamController?.stream;
  bool get isRecording => _isRecording;

  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Check permissions for mobile platforms
      if (!kIsWeb) {
        final status = await Permission.microphone.status;
        if (!status.isGranted) {
          final result = await Permission.microphone.request();
          if (!result.isGranted) {
            return false;
          }
        }
      }

      _audioStreamController = StreamController<Uint8List>.broadcast();
      _isInitialized = true;
      return true;
    } catch (e) {
      debugPrint('Error initializing audio service: $e');
      return false;
    }
  }

  Future<bool> startRecording() async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) return false;
    }

    if (_isRecording) return true;

    try {
      // Configure recording settings for OpenAI Realtime API
      // OpenAI expects PCM16 format with 24kHz sample rate
      const config = RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 24000,
        numChannels: 1,
        bitRate: 384000, // 24kHz * 16 bits * 1 channel
      );

      final stream = await _recorder.startStream(config);
      _isRecording = true;

      // Process audio stream and convert to the format expected by OpenAI
      stream.listen(
        (data) {
          if (_audioStreamController != null && !_audioStreamController!.isClosed) {
            debugPrint('AudioService: Received audio data (${data.length} bytes)');
            _audioStreamController!.add(data);
          }
        },
        onError: (error) {
          debugPrint('Audio stream error: $error');
        },
      );

      return true;
    } catch (e) {
      debugPrint('Error starting recording: $e');
      return false;
    }
  }

  Future<void> stopRecording() async {
    if (!_isRecording) return;

    try {
      await _recorder.stop();
      _isRecording = false;
    } catch (e) {
      debugPrint('Error stopping recording: $e');
    }
  }

  Future<void> dispose() async {
    await stopRecording();
    await _audioStreamController?.close();
    await _recorder.dispose();
    _isInitialized = false;
  }

  // Convert audio data to base64 for OpenAI API
  String audioToBase64(Uint8List audioData) {
    return base64Encode(audioData);
  }
}