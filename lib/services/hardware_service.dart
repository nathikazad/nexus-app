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

  Uint8List _batch = Uint8List(0);
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
      _sendAudioToEsp32();
      
      _isInitialized = true;
      return true;
    } catch (e) {
      debugPrint('Error initializing HardwareService: $e');
      return false;
    }
  }


    /// Transforms Opus packets and sends them to ESP32
  Future<void> _sendAudioToEsp32() async {
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
      
      // Send Opus packets as they're produced
      final mtu = _bleService.getMTU();
      
      await for (final opusPacket in opusPacketStream) {
        // Create packet: [length (2 bytes)] + [opus data]
        Uint8List packet = Uint8List(2 + opusPacket.length);
        packet[0] = opusPacket.length & 0xFF;
        packet[1] = (opusPacket.length >> 8) & 0xFF;
        packet.setRange(2, 2 + opusPacket.length, opusPacket);
        
        await _bleService.waitIfPaused();
        
        // If adding would exceed MTU, send current batch
        if (_batch.length + packet.length > mtu && _batch.isNotEmpty) {
          await _bleService.sendBatch(_batch);
          _batch = Uint8List(0);
          await Future.delayed(const Duration(milliseconds: 20));
        }
        
        // Add packet to batch
        Uint8List newBatch = Uint8List(_batch.length + packet.length);
        if (_batch.isNotEmpty) {
          newBatch.setRange(0, _batch.length, _batch);
        }
        newBatch.setRange(_batch.length, _batch.length + packet.length, packet);
        _batch = newBatch;
        
        _framesSent++;
        debugPrint('[SEND] Processed frame $_framesSent (${opusPacket.length} bytes Opus, batch size: ${_batch.length} bytes)');
          await Future.delayed(const Duration(milliseconds: 5));
      }
    } catch (e) {
      debugPrint('Error sending WAV to ESP32: $e');
      
      rethrow;
    }
  }

  Future<void> sendEOFToEsp32() async {
    // Send remaining batch
      if (_batch.isNotEmpty) {
        await _bleService.sendBatch(_batch);
        debugPrint('[SEND] Sent final batch: ${_batch.length} bytes');
      }
      
      // Send EOF signal
      debugPrint('[SEND] Sent EOF signal. Total frames sent: $_framesSent');
      const int signalEof = 0x0000;
      Uint8List eofPacket = Uint8List(2);
      eofPacket[0] = signalEof & 0xFF;
      eofPacket[1] = (signalEof >> 8) & 0xFF;
      // send after 1 second
      await Future.delayed(const Duration(seconds: 1));
      await _bleService.sendPacket(eofPacket);
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

