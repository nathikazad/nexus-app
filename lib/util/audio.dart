import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:opus_dart/opus_dart.dart';

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
/// Buffers incoming PCM24 chunks and emits fixed 60ms chunks (2880 bytes PCM24 -> 1920 bytes PCM16)
class Pcm24ToPcm16Transformer extends StreamTransformerBase<Uint8List, Uint8List> {
  static const int expectedPcm16Bytes = 1920; // 960 samples * 2 bytes = 60ms at 16kHz
  static const int expectedPcm24Bytes = 2880; // 1440 samples * 2 bytes = 60ms at 24kHz
  
  @override
  Stream<Uint8List> bind(Stream<Uint8List> stream) {
    Uint8List buffer = Uint8List(0);
    
    return stream.asyncExpand((pcm24Chunk) async* {
      // Append incoming chunk to buffer
      final newBuffer = Uint8List(buffer.length + pcm24Chunk.length);
      if (buffer.isNotEmpty) {
        newBuffer.setRange(0, buffer.length, buffer);
      }
      newBuffer.setRange(buffer.length, newBuffer.length, pcm24Chunk);
      buffer = newBuffer;
      
      // Process complete 60ms chunks from buffer
      while (buffer.length >= expectedPcm24Bytes) {
        // Extract exactly 60ms chunk (2880 bytes)
        final chunk24 = buffer.sublist(0, expectedPcm24Bytes);
        buffer = buffer.sublist(expectedPcm24Bytes);
        
        // Resample to PCM16
        final resampled = AudioProcessor.resamplePcm24To16(chunk24);
        
        // Validate output size - should be exactly 1920 bytes for 60ms chunks
        if (resampled.length != expectedPcm16Bytes) {
          debugPrint('[RESAMPLE] WARNING: Resampled chunk size ${resampled.length} != expected $expectedPcm16Bytes bytes');
          debugPrint('[RESAMPLE] Input was ${chunk24.length} bytes (${chunk24.length ~/ 2} samples at 24kHz)');
          debugPrint('[RESAMPLE] Output is ${resampled.length} bytes (${resampled.length ~/ 2} samples at 16kHz)');
        }
        
        yield resampled;
      }
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

// ============================================================================
// AUDIO PROCESSING MODULE
// ============================================================================

class AudioProcessor {
  static const int defaultSampleRate = 16000;
  static const int defaultChannels = 1;
  
  /// Creates a new Opus decoder for streaming
  static StreamOpusDecoder createDecoder({
    int sampleRate = defaultSampleRate,
    int channels = defaultChannels,
  }) {
    return StreamOpusDecoder.bytes(
      floatOutput: false,
      sampleRate: sampleRate,
      channels: channels,
      copyOutput: true,
      forwardErrorCorrection: false,
    );
  }
  
  /// Decodes Opus packets to PCM16
  static Future<Uint8List> decodeOpusPackets(
    List<Uint8List> opusPackets, {
    int sampleRate = defaultSampleRate,
    int channels = defaultChannels,
  }) async {
    if (opusPackets.isEmpty) {
      throw Exception('No Opus packets to decode');
    }

    final decoder = createDecoder(sampleRate: sampleRate, channels: channels);
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

    return result;
  }
  
  /// Resamples PCM16 from 16kHz to 24kHz
  static Uint8List resamplePcm16To24(Uint8List pcm16Data) {
    const int inputSampleRate = 16000;
    const int outputSampleRate = 24000;
    const double ratio = outputSampleRate / inputSampleRate;
    const int bytesPerSample = 2;
    
    int inputSampleCount = pcm16Data.length ~/ bytesPerSample;
    int outputSampleCount = (inputSampleCount * ratio).round();
    int outputLength = outputSampleCount * bytesPerSample;
    
    Uint8List output = Uint8List(outputLength);
    Int16List inputSamples = Int16List.view(
      pcm16Data.buffer, 
      pcm16Data.offsetInBytes, 
      inputSampleCount
    );
    Int16List outputSamples = Int16List.view(
      output.buffer, 
      output.offsetInBytes, 
      outputSampleCount
    );
    
    for (int i = 0; i < outputSampleCount; i++) {
      double inputIndex = i / ratio;
      int inputIndexFloor = inputIndex.floor();
      int inputIndexCeil = (inputIndex + 1).floor();
      double fraction = inputIndex - inputIndexFloor;
      
      if (inputIndexCeil >= inputSampleCount) {
        inputIndexCeil = inputSampleCount - 1;
      }
      
      int sample1 = inputSamples[inputIndexFloor];
      int sample2 = inputSamples[inputIndexCeil];
      int interpolated = (sample1 + (sample2 - sample1) * fraction).round();
      
      outputSamples[i] = interpolated;
    }
    
    return output;
  }
  
  /// Resamples PCM24 from 24kHz to 16kHz
  /// Ensures exact output size: for 1440 samples input (60ms at 24kHz), outputs exactly 960 samples (60ms at 16kHz)
  static Uint8List resamplePcm24To16(Uint8List pcm24Data) {
    const int inputSampleRate = 24000;
    const int outputSampleRate = 16000;
    const int bytesPerSample = 2;
    
    int inputSampleCount = pcm24Data.length ~/ bytesPerSample;
    // Calculate exact output sample count: input * 2/3, using integer math to avoid rounding errors
    // For 1440 samples: 1440 * 2 / 3 = 960 exactly
    int outputSampleCount = (inputSampleCount * outputSampleRate) ~/ inputSampleRate;
    int outputLength = outputSampleCount * bytesPerSample;
    
    Uint8List output = Uint8List(outputLength);
    Int16List inputSamples = Int16List.view(
      pcm24Data.buffer, 
      pcm24Data.offsetInBytes, 
      inputSampleCount
    );
    Int16List outputSamples = Int16List.view(
      output.buffer, 
      output.offsetInBytes, 
      outputSampleCount
    );
    
    const double ratio = inputSampleRate / outputSampleRate; // 24/16 = 1.5
    for (int i = 0; i < outputSampleCount; i++) {
      // Use exact ratio calculation: i * inputRate / outputRate
      double inputIndex = i * ratio;
      int inputIndexFloor = inputIndex.floor();
      int inputIndexCeil = (inputIndex + 1).floor();
      double fraction = inputIndex - inputIndexFloor;
      
      if (inputIndexCeil >= inputSampleCount) {
        inputIndexCeil = inputSampleCount - 1;
      }
      
      int sample1 = inputSamples[inputIndexFloor];
      int sample2 = inputSamples[inputIndexCeil];
      int interpolated = (sample1 + (sample2 - sample1) * fraction).round();
      
      outputSamples[i] = interpolated;
    }
    
    return output;
  }
}
