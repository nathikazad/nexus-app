import 'dart:async';
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
  List<Uint8List> _audioDataChunks = [];

  Stream<Uint8List>? get audioStream => _audioStreamController?.stream;
  bool get isRecording => _isRecording;

  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Check permissions for mobile platforms
      if (!kIsWeb) {
        final status = await Permission.microphone.status;
        print('Microphone permission status: $status');
        if (!status.isGranted) {
          print('Requesting microphone permission');
          final result = await Permission.microphone.request();
          if (!result.isGranted) {
            print('Microphone permission not granted');
            return false;
          } else {
            print('Microphone permission granted');
          }
        } else {
          print('Microphone permission already granted');
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
      // Initialize audio data storage
      _audioDataChunks.clear();

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

      // Process audio stream and send directly to the controller
      // The audio data is already in the correct PCM format for OpenAI
      stream.listen(
        (data) {
          if (_audioStreamController != null && !_audioStreamController!.isClosed) {
            _audioStreamController!.add(data);
            // Store audio chunks in memory
            _audioDataChunks.add(data);
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
      _audioDataChunks.clear();
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
}