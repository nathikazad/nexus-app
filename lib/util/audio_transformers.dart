import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:opus_dart/opus_dart.dart';
import '../main_ble.dart'; // For AudioProcessor

// ============================================================================
// STREAM TRANSFORMER MODULE
// ============================================================================

/// Transforms Opus packets to PCM16 chunks by decoding
class OpusToPcm16Transformer extends StreamTransformerBase<Uint8List, Uint8List> {
  final StreamOpusDecoder decoder;
  
  OpusToPcm16Transformer(this.decoder);
  
  @override
  Stream<Uint8List> bind(Stream<Uint8List> stream) {
    return stream.asyncExpand((opusPacket) async* {
      try {
        final decodedStream = decoder.bind(Stream.value(opusPacket));
        await for (final pcm16Chunk in decodedStream) {
          if (pcm16Chunk is Uint8List && pcm16Chunk.isNotEmpty) {
            yield pcm16Chunk;
          }
        }
      } catch (e) {
        debugPrint('Error in OpusToPcm16Transformer: $e');
        // Don't yield anything on error, just log it
      }
    });
  }
}

/// Transforms PCM16 chunks to PCM24 chunks by resampling
class Pcm16ToPcm24Transformer extends StreamTransformerBase<Uint8List, Uint8List> {
  @override
  Stream<Uint8List> bind(Stream<Uint8List> stream) {
    return stream.map((pcm16Chunk) {
      return AudioProcessor.resamplePcm16To24(pcm16Chunk);
    });
  }
}

/// Transforms PCM24 chunks to PCM16 chunks by resampling
class Pcm24ToPcm16Transformer extends StreamTransformerBase<Uint8List, Uint8List> {
  static const int expectedPcm16Bytes = 1920; // 960 samples * 2 bytes = 60ms at 16kHz
  
  @override
  Stream<Uint8List> bind(Stream<Uint8List> stream) {
    return stream.map((pcm24Chunk) {
      final resampled = AudioProcessor.resamplePcm24To16(pcm24Chunk);
      
      // Validate output size - should be exactly 1920 bytes for 60ms chunks
      if (resampled.length != expectedPcm16Bytes) {
        debugPrint('[RESAMPLE] WARNING: Resampled chunk size ${resampled.length} != expected $expectedPcm16Bytes bytes');
        debugPrint('[RESAMPLE] Input was ${pcm24Chunk.length} bytes (${pcm24Chunk.length ~/ 2} samples at 24kHz)');
        debugPrint('[RESAMPLE] Output is ${resampled.length} bytes (${resampled.length ~/ 2} samples at 16kHz)');
      }
      
      return resampled;
    });
  }
}

/// Transforms PCM16 chunks to Opus packets by encoding
/// Processes all chunks through a single encoder stream for proper state management
class Pcm16ToOpusTransformer extends StreamTransformerBase<Uint8List, Uint8List> {
  final StreamOpusEncoder encoder;
  static const int expectedPcm16Bytes = 1920; // 960 samples * 2 bytes = 60ms at 16kHz
  
  Pcm16ToOpusTransformer(this.encoder);
  
  @override
  Stream<Uint8List> bind(Stream<Uint8List> stream) {
    // Process all chunks through a single encoder stream
    // This ensures the encoder maintains proper state across chunks
    return encoder.bind(stream.map((pcm16Chunk) {
      // Validate chunk size before encoding
      if (pcm16Chunk.length != expectedPcm16Bytes) {
        debugPrint('[ENCODE] ERROR: PCM16 chunk size ${pcm16Chunk.length} != expected $expectedPcm16Bytes bytes');
        debugPrint('[ENCODE] Input was ${pcm16Chunk.length} bytes (${pcm16Chunk.length ~/ 2} samples)');
        throw Exception('Invalid PCM16 chunk size: ${pcm16Chunk.length} bytes, expected $expectedPcm16Bytes bytes');
      }
      return pcm16Chunk;
    })).where((opusPacket) => opusPacket.isNotEmpty);
  }
}

