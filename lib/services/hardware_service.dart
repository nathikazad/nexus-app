import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:nexus_voice_assistant/services/openai_service.dart';
import 'package:opus_dart/opus_dart.dart';
import '../services/ble_service.dart';
import '../util/audio.dart';

class HardwareService {
  static final HardwareService _instance = HardwareService._internal();
  
  /// Singleton instance getter
  static HardwareService get instance => _instance;
  
  factory HardwareService() => _instance;
  HardwareService._internal();

  final BLEService _bleService = BLEService.instance;
  
  StreamOpusDecoder? _streamDecoder;
  OpusToPcm16Transformer? _opusToPcm16Transformer;
  Pcm16ToPcm24Transformer? _pcm16ToPcm24Transformer;
  
  StreamSubscription<Uint8List>? _opusPacketSubscription;
  StreamSubscription<Uint8List>? _pcm24ChunkSubscription;
  StreamSubscription<void>? _eofSubscription;
  
  Stream<Uint8List>? _pcm24Stream;
  
  bool _isInitialized = false;

  Stream<Uint8List>? get pcm24Stream => _pcm24Stream;
  bool get isInitialized => _isInitialized;

  int _framesSent = 0;

  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Wait for BLE service to be initialized
      await _bleService.initialize();
      
      // Create decoder and transformers
      _streamDecoder = AudioProcessor.createDecoder();
      _opusToPcm16Transformer = OpusToPcm16Transformer(_streamDecoder!);
      _pcm16ToPcm24Transformer = Pcm16ToPcm24Transformer();
      
      // Set up the stream pipeline: Opus packets -> PCM16 -> PCM24 chunks
      final opusStream = _bleService.opusPacketStream;
      final eofStream = _bleService.eofStream;
      
      if (opusStream == null) {
        debugPrint('HardwareService: opusPacketStream is null');
        return false;
      }
      
      if (eofStream == null) {
        debugPrint('HardwareService: eofStream is null');
        return false;
      }
      
      final pcm16Stream = opusStream.transform(_opusToPcm16Transformer!);
      final pcm24Stream = pcm16Stream.transform(_pcm16ToPcm24Transformer!);
      
      // Store the PCM24 stream
      _pcm24Stream = pcm24Stream;

      // Store the Opus packet subscription
      _opusPacketSubscription = opusStream.listen(
        (opusPacket) {
          debugPrint('HardwareService: Received Opus packet: ${opusPacket.length} bytes');
        },
        onError: (e) {
          debugPrint('HardwareService: Error in Opus stream: $e');
        },
      );
      
      // Listen for PCM24 chunks (transformed from Opus packets)
      _pcm24ChunkSubscription = pcm24Stream.listen(
        (pcm24Chunk) {
          debugPrint('HardwareService: Processed PCM24 chunk: ${pcm24Chunk.length} bytes');
          OpenAIService.instance.sendAudio(pcm24Chunk, queryOrigin.Hardware);
        },
        onError: (e) {
          debugPrint('HardwareService: Error in PCM24 stream: $e');
        },
      );

      // Listen for EOF stream
      _eofSubscription = eofStream.listen(
        (_) {
          debugPrint('HardwareService: EOF received');
          OpenAIService.instance.createResponse();
        },
        onError: (e) {
          debugPrint('HardwareService: Error in EOF stream: $e');
        },
      );
      _startOpenAiToBleRelayer();
      
      _isInitialized = true;
      return true;
    } catch (e) {
      debugPrint('Error initializing HardwareService: $e');
      return false;
    }
  }


  /// Transforms Opus packets and queues them for sending to ESP32
  Future<void> _startOpenAiToBleRelayer() async {
    try {
      const int sampleRate = 16000;
      const int channels = 1;
    
      // Create Opus encoder for 60ms frames
      final encoder = StreamOpusEncoder.bytes(
        floatInput: false,
        frameTime: FrameTime.ms60,
        sampleRate: sampleRate,
        channels: channels,
        application: Application.audio,
        copyOutput: true,
        fillUpLastFrame: true,
      );
      
      // Create transformers
      final resampleTransformer = Pcm24ToPcm16Transformer();
      final encodeTransformer = Pcm16ToOpusTransformer(encoder);
      
      // Build the stream pipeline:
      // WAV file -> 60ms PCM24 chunks -> Resample to PCM16 -> Encode to Opus
      final pcm24ChunkStream = OpenAIService.instance.hardWareAudioOutStream;
      final pcm16ChunkStream = pcm24ChunkStream.transform(resampleTransformer);
      final opusPacketStream = pcm16ChunkStream.transform(encodeTransformer);
      
      // Create packets and enqueue them for sending
      await for (final opusPacket in opusPacketStream) {
        // Create packet: [length (2 bytes)] + [opus data]
        Uint8List packet = Uint8List(2 + opusPacket.length);
        packet[0] = opusPacket.length & 0xFF;
        packet[1] = (opusPacket.length >> 8) & 0xFF;
        packet.setRange(2, 2 + opusPacket.length, opusPacket);
        
        // Enqueue packet - BLE service will handle batching and sending
        _bleService.enqueuePacket(packet);
        
        _framesSent++;
        debugPrint('[QUEUE] Enqueued frame $_framesSent (${opusPacket.length} bytes Opus)');
      }
    } catch (e) {
      debugPrint('Error sending WAV to ESP32: $e');
      rethrow;
    }
  }

  Future<void> sendEOFToEsp32() async {
    // Enqueue EOF packet - it will be sent after all queued audio packets
    debugPrint('[QUEUE] Enqueuing EOF signal. Total frames sent: $_framesSent');
    _bleService.enqueueEOF();
  }

  Future<void> dispose() async {
    await _opusPacketSubscription?.cancel();
    await _pcm24ChunkSubscription?.cancel();
    await _eofSubscription?.cancel();
    
    _opusPacketSubscription = null;
    _pcm24ChunkSubscription = null;
    _eofSubscription = null;
    _streamDecoder = null;
    _opusToPcm16Transformer = null;
    _pcm16ToPcm24Transformer = null;
    _pcm24Stream = null;
    _isInitialized = false;
  }
}

