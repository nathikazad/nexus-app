import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:opus_dart/opus_dart.dart';
import 'package:opus_flutter/opus_flutter.dart' as opus_flutter;
import 'package:path_provider/path_provider.dart';
import 'package:universal_html/html.dart' as html;

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final AudioRecorder _recorder = AudioRecorder();
  StreamController<Uint8List>? _audioStreamController;
  bool _isRecording = false;
  bool _isInitialized = false;
  bool _opusMode = false;
  IOSink? _fileSink;
  String? _currentRecordingPath;
  List<Uint8List> _audioDataChunks = [];
  List<Uint8List> _opusAccumulator = []; // For accumulating data in Opus mode

  Stream<Uint8List>? get audioStream => _audioStreamController?.stream;
  bool get isRecording => _isRecording;
  
  void setOpusMode(bool enabled) {
    _opusMode = enabled;
    debugPrint('Opus mode ${enabled ? 'enabled' : 'disabled'}');
  }

  Future<void> _processOpusMode(Uint8List data, {bool forceProcess = false}) async {
    // Add data to accumulator (unless forcing processing of remaining data)
    if (data.isNotEmpty) {
      _opusAccumulator.add(data);
    }
    
    // Check if we have enough data for a complete frame or if we're forcing processing
    const int frameSizeBytes = 960; // 20ms at 24kHz, 16-bit, mono
    int totalAccumulated = _opusAccumulator.fold(0, (sum, chunk) => sum + chunk.length);
    
    if (totalAccumulated >= frameSizeBytes || (forceProcess && totalAccumulated > 0)) {
      // Combine chunks to get complete frames
      Uint8List combinedData = Uint8List(totalAccumulated);
      int offset = 0;
      for (Uint8List chunk in _opusAccumulator) {
        combinedData.setRange(offset, offset + chunk.length, chunk);
        offset += chunk.length;
      }
      
      // Encode to Opus packets
      List<Uint8List> opusPackets = await encodeAudioToOpusPackets(combinedData);
      
      // Decode back to PCM for processing
      Uint8List pcmData = await decodeAudioFromOpusPackets(opusPackets);
      
      // Send to stream controller
      if (_audioStreamController != null && !_audioStreamController!.isClosed) {
        _audioStreamController!.add(pcmData);
      }
      
      // Save the PCM data
      if (kIsWeb) {
        _audioDataChunks.add(pcmData);
      } else {
        _fileSink?.add(pcmData);
      }
      
      // Clear processed data
      _opusAccumulator.clear();
    }
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
      // Initialize audio data storage
      _audioDataChunks.clear();
      _opusAccumulator.clear();
      
      if (!kIsWeb) {
        // For mobile platforms, create a file to save the PCM data
        final directory = await getApplicationDocumentsDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        _currentRecordingPath = '${directory.path}/recording_$timestamp.pcm';
        _fileSink = File(_currentRecordingPath!).openWrite();
      } else {
        // For web, we'll store data in memory and create a blob URL later
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        _currentRecordingPath = 'recording_$timestamp.pcm';
      }

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
              await _processOpusMode(data);
            } else {
              _audioStreamController!.add(data);
              // Save the PCM data
              if (kIsWeb) {
                _audioDataChunks.add(data);
              } else {
                _fileSink?.add(data);
              }
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

  static Future<List<Uint8List>> encodeAudioToOpusPackets(Uint8List audioData) async {
    try {
      const int sampleRate = 24000; // Match your recording sample rate
      const int channels = 1;
      
      // Split PCM data into proper frame sizes for Opus encoding
      // For 20ms frames at 24kHz: 24000 * 0.02 * 2 bytes = 960 bytes per frame
      const int frameSizeBytes = 960; // 20ms at 24kHz, 16-bit, mono
      List<Uint8List> pcmFrames = [];
      
      for (int i = 0; i < audioData.length; i += frameSizeBytes) {
        int end = (i + frameSizeBytes < audioData.length) ? i + frameSizeBytes : audioData.length;
        pcmFrames.add(audioData.sublist(i, end));
      }
      
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
      
      // Encode each frame
      List<Uint8List> opusPackets = [];
      await for (final packet in encoder.bind(Stream.fromIterable(pcmFrames))) {
        opusPackets.add(packet);
      }
      
      debugPrint('Opus encode: ${audioData.length} bytes PCM -> ${opusPackets.length} packets');
      return opusPackets;
    } catch (e) {
      debugPrint('Error encoding audio to Opus: $e');
      rethrow;
    }
  }

  static Future<Uint8List> decodeAudioFromOpusPackets(List<Uint8List> opusPackets) async {
    try {
      const int sampleRate = 24000; // Match your recording sample rate
      const int channels = 1;
      
      if (opusPackets.isEmpty) {
        throw Exception('No Opus packets to decode');
      }
      
      // Create the decoder
      final decoder = StreamOpusDecoder.bytes(
        floatOutput: false,
        sampleRate: sampleRate,
        channels: channels,
        copyOutput: true,
        forwardErrorCorrection: false,
      );
      
      // Decode each packet individually
      List<Uint8List> decodedChunks = [];
      await for (final chunk in decoder.bind(Stream.fromIterable(opusPackets))) {
        if (chunk is Uint8List) {
          decodedChunks.add(chunk);
        }
      }
      
      // Combine all decoded chunks
      int totalLength = decodedChunks.fold(0, (sum, chunk) => sum + chunk.length);
      Uint8List result = Uint8List(totalLength);
      int offset = 0;
      for (Uint8List chunk in decodedChunks) {
        if (offset + chunk.length <= result.length) {
          result.setRange(offset, offset + chunk.length, chunk);
          offset += chunk.length;
        }
      }
      
      debugPrint('Opus decode: ${opusPackets.length} packets -> ${result.length} bytes');
      return result;
    } catch (e) {
      debugPrint('Error decoding audio from Opus packets: $e');
      rethrow;
    }
  }

  Future<String?> stopRecording() async {
    if (!_isRecording) return null;

    try {
      await _recorder.stop();
      _isRecording = false;
      
      // Process any remaining data in Opus accumulator
      if (_opusMode && _opusAccumulator.isNotEmpty) {
        await _processOpusMode(Uint8List(0), forceProcess: true); // Process remaining data
      }
      
      String? filePath;
      
      if (kIsWeb) {
        // For web, create a blob URL from the collected audio data
        if (_audioDataChunks.isNotEmpty) {
          // Combine all audio chunks
          int totalLength = _audioDataChunks.fold(0, (sum, chunk) => sum + chunk.length);
          Uint8List combinedPcmData = Uint8List(totalLength);
          int offset = 0;
          for (Uint8List chunk in _audioDataChunks) {
            combinedPcmData.setRange(offset, offset + chunk.length, chunk);
            offset += chunk.length;
          }
          
          // Convert PCM to WAV format for web compatibility
          final wavData = pcmToWav(combinedPcmData);
          
          // Create blob and URL with WAV MIME type
          final blob = html.Blob([wavData], 'audio/wav');
          filePath = html.Url.createObjectUrl(blob);
        }
        _audioDataChunks.clear();
      } else {
        // For mobile platforms, close the file sink and convert to WAV
        await _fileSink?.close();
        _fileSink = null;
        
        if (_currentRecordingPath != null) {
          // Read the PCM file and convert to WAV
          final pcmFile = File(_currentRecordingPath!);
          if (await pcmFile.exists()) {
            final pcmData = await pcmFile.readAsBytes();
            final wavData = pcmToWav(pcmData);
            
            // Create WAV file path
            final wavPath = _currentRecordingPath!.replaceAll('.pcm', '.wav');
            final wavFile = File(wavPath);
            await wavFile.writeAsBytes(wavData);
            
            // Delete the original PCM file
            await pcmFile.delete();
            
            filePath = wavPath;
          }
        }
      }
      
      _currentRecordingPath = null;
      return filePath;
    } catch (e) {
      debugPrint('Error stopping recording: $e');
      return null;
    }
  }

  Future<void> dispose() async {
    await stopRecording();
    await _fileSink?.close();
    await _audioStreamController?.close();
    await _recorder.dispose();
    _isInitialized = false;
  }

  // Convert audio data to base64 for OpenAI API
  String audioToBase64(Uint8List audioData) {
    return base64Encode(audioData);
  }

  // Convert PCM data to WAV format with proper headers
  Uint8List pcmToWav(Uint8List pcmData, {int sampleRate = 24000, int channels = 1, int bitsPerSample = 16}) {
    final int dataSize = pcmData.length;
    final int fileSize = 36 + dataSize;
    
    final ByteData wavHeader = ByteData(44);
    
    // RIFF header
    wavHeader.setUint8(0, 0x52); // 'R'
    wavHeader.setUint8(1, 0x49); // 'I'
    wavHeader.setUint8(2, 0x46); // 'F'
    wavHeader.setUint8(3, 0x46); // 'F'
    wavHeader.setUint32(4, fileSize, Endian.little);
    wavHeader.setUint8(8, 0x57);  // 'W'
    wavHeader.setUint8(9, 0x41);  // 'A'
    wavHeader.setUint8(10, 0x56); // 'V'
    wavHeader.setUint8(11, 0x45); // 'E'
    
    // fmt chunk
    wavHeader.setUint8(12, 0x66); // 'f'
    wavHeader.setUint8(13, 0x6D); // 'm'
    wavHeader.setUint8(14, 0x74); // 't'
    wavHeader.setUint8(15, 0x20); // ' '
    wavHeader.setUint32(16, 16, Endian.little); // fmt chunk size
    wavHeader.setUint16(20, 1, Endian.little);  // audio format (PCM)
    wavHeader.setUint16(22, channels, Endian.little);
    wavHeader.setUint32(24, sampleRate, Endian.little);
    wavHeader.setUint32(28, sampleRate * channels * bitsPerSample ~/ 8, Endian.little); // byte rate
    wavHeader.setUint16(32, channels * bitsPerSample ~/ 8, Endian.little); // block align
    wavHeader.setUint16(34, bitsPerSample, Endian.little);
    
    // data chunk
    wavHeader.setUint8(36, 0x64); // 'd'
    wavHeader.setUint8(37, 0x61); // 'a'
    wavHeader.setUint8(38, 0x74); // 't'
    wavHeader.setUint8(39, 0x61); // 'a'
    wavHeader.setUint32(40, dataSize, Endian.little);
    
    // Combine header and PCM data
    final Uint8List wavData = Uint8List(44 + dataSize);
    wavData.setRange(0, 44, wavHeader.buffer.asUint8List());
    wavData.setRange(44, 44 + dataSize, pcmData);
    
    return wavData;
  }
}