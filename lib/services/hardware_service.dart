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
      
      _isInitialized = true;
      return true;
    } catch (e) {
      debugPrint('Error initializing HardwareService: $e');
      return false;
    }
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

