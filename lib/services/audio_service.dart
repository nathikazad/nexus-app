import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:opus_dart/opus_dart.dart';
import 'package:opus_flutter/opus_flutter.dart' as opus_flutter;

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final AudioRecorder _recorder = AudioRecorder();
  StreamController<Uint8List>? _audioStreamController;
  bool _isRecording = false;
  bool _isInitialized = false;
  bool _opusMode = false;

  Stream<Uint8List>? get audioStream => _audioStreamController?.stream;
  bool get isRecording => _isRecording;
  
  void setOpusMode(bool enabled) {
    _opusMode = enabled;
    debugPrint('Opus mode ${enabled ? 'enabled' : 'disabled'}');
  }

  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Initialize Opus
      try {
        initOpus(await opus_flutter.load());
        debugPrint('Opus initialized successfully');
      } catch (e) {
        debugPrint('Error initializing Opus: $e');
      }

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
        (data) async {
          if (_audioStreamController != null && !_audioStreamController!.isClosed) {
            
            if (_opusMode) {
            final opusData = await encodeAudioToOpus(data);
              final pcmData = await decodeAudioFromOpus(opusData);
              _audioStreamController!.add(pcmData);
            } else {
              _audioStreamController!.add(data);
            }
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

  Future<Uint8List> encodeAudioToOpus(Uint8List audioData) async {
    try {
      const int sampleRate = 24000; // Match your recording sample rate
      const int channels = 1;
      
      // Create a stream from the audio data - ensure it's Uint8List
      Stream<Uint8List> audioStream = Stream.value(audioData);
      
      // Create the encoder
      final encoder = StreamOpusEncoder.bytes(
        floatInput: false,
        frameTime: FrameTime.ms20,
        sampleRate: sampleRate,
        channels: channels,
        application: Application.audio,
        copyOutput: true,
        fillUpLastFrame: true,
      );
      
      // Encode to Opus using the bind method
      List<Uint8List> encodedChunks = [];
      await for (final chunk in encoder.bind(audioStream)) {
        encodedChunks.add(chunk);
      }
      
      // Combine all encoded chunks
      int totalLength = encodedChunks.fold(0, (sum, chunk) => sum + chunk.length);
      Uint8List result = Uint8List(totalLength);
      int offset = 0;
      for (Uint8List chunk in encodedChunks) {
        result.setRange(offset, offset + chunk.length, chunk);
        offset += chunk.length;
      }
      
      debugPrint('Opus encode: encoded ${audioData.length} bytes to ${result.length} bytes');
      return result;
    } catch (e) {
      debugPrint('Error encoding audio to Opus: $e');
      return audioData; // Return original data if encoding fails
    }
  }

  Future<Uint8List> decodeAudioFromOpus(Uint8List opusData) async {
    try {
      const int sampleRate = 24000; // Match your recording sample rate
      const int channels = 1;
      
      // Create a stream from the Opus data - StreamOpusDecoder expects Stream<Uint8List?>
      Stream<Uint8List?> opusStream = Stream.value(opusData);
      
      // Create the decoder using the correct constructor
      final decoder = StreamOpusDecoder.bytes(
        floatOutput: false,
        sampleRate: sampleRate,
        channels: channels,
        copyOutput: true,
        forwardErrorCorrection: false,
      );
      
      // Use the bind method directly as shown in the opus_dart implementation
      List<Uint8List> decodedChunks = [];
      await for (final chunk in decoder.bind(opusStream)) {
        if (chunk is Uint8List) {
          decodedChunks.add(chunk);
        }
      }
      
      // Combine all decoded chunks
      int totalLength = decodedChunks.fold(0, (sum, chunk) => sum + chunk.length);
      Uint8List result = Uint8List(totalLength);
      int offset = 0;
      for (Uint8List chunk in decodedChunks) {
        result.setRange(offset, offset + chunk.length, chunk);
        offset += chunk.length;
      }
      
      debugPrint('Opus decode: decoded ${opusData.length} bytes to ${result.length} bytes');
      return result;
    } catch (e) {
      debugPrint('Error decoding audio from Opus: $e');
      return opusData; // Return original data if decoding fails
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