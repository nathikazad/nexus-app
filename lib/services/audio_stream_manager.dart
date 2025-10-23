import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

class AudioStreamManager {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final List<Uint8List> _streamedAudioChunks = [];
  bool _isPlayingStreamedAudio = false;
  StreamSubscription? _audioPlayerSubscription;

  // Callback for when audio playback state changes
  Function(bool)? onPlaybackStateChanged;

  AudioStreamManager();

  /// Add audio data to the streaming queue
  Future<void> playStreamedAudio(Uint8List audioData) async {
    try {
      // Add audio chunk to the list
      _streamedAudioChunks.add(audioData);
      
      // If we're not already playing streamed audio, start playing
      if (!_isPlayingStreamedAudio) {
        _isPlayingStreamedAudio = true;
        onPlaybackStateChanged?.call(true);
        _setupAudioPlayerListener();
        _playNextAudioChunk();
      }
    } catch (e) {
      debugPrint('Error handling streamed audio: $e');
    }
  }

  /// Set up a single listener for audio completion
  void _setupAudioPlayerListener() {
    // Cancel any existing listener
    _audioPlayerSubscription?.cancel();
    
    // Set up a single listener for audio completion
    _audioPlayerSubscription = _audioPlayer.onPlayerComplete.listen((_) {
      // Play next chunk if available
      if (_streamedAudioChunks.isNotEmpty) {
        _playNextAudioChunk();
      } else {
        _isPlayingStreamedAudio = false;
        onPlaybackStateChanged?.call(false);
        _audioPlayerSubscription?.cancel();
      }
    });
  }

  /// Play the next audio chunk in the queue
  Future<void> _playNextAudioChunk() async {
    if (_streamedAudioChunks.isEmpty) {
      _isPlayingStreamedAudio = false;
      onPlaybackStateChanged?.call(false);
      _audioPlayerSubscription?.cancel();
      return;
    }

    try {
      // Take the first chunk
      final audioChunk = _streamedAudioChunks.removeAt(0);
      final wavData = _convertPcmToWav(audioChunk);
      
      if (kIsWeb) {
        // For web, create a blob URL
        await _playWebAudioChunk(wavData);
      } else {
        // For mobile, create a temporary file
        await _playMobileAudioChunk(wavData);
      }
      
    } catch (e) {
      debugPrint('Error playing audio chunk: $e');
      _isPlayingStreamedAudio = false;
      onPlaybackStateChanged?.call(false);
      _audioPlayerSubscription?.cancel();
    }
  }

  /// Play audio chunk on web platform
  Future<void> _playWebAudioChunk(Uint8List wavData) async {
    try {
      // Convert the WAV data to a base64 data URL
      final base64Audio = Uri.dataFromBytes(wavData, mimeType: 'audio/wav').toString();
      
      // Play the audio using the data URL
      await _audioPlayer.play(UrlSource(base64Audio));
      
    } catch (e) {
      debugPrint('Error playing web audio chunk: $e');
      _isPlayingStreamedAudio = false;
      onPlaybackStateChanged?.call(false);
    }
  }

  /// Play audio chunk on mobile platform
  Future<void> _playMobileAudioChunk(Uint8List wavData) async {
    try {
      // Create a temporary file for this audio chunk
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/streamed_audio_${DateTime.now().millisecondsSinceEpoch}.wav');
      await tempFile.writeAsBytes(wavData);
      
      // Play the audio chunk
      await _audioPlayer.play(DeviceFileSource(tempFile.path));
      
      // Schedule cleanup of the temporary file after a delay
      // (We can't clean it up immediately as the audio player might still need it)
      Timer(const Duration(seconds: 30), () {
        tempFile.delete().catchError((e) {
          debugPrint('Error deleting temp file: $e');
          return tempFile;
        });
      });
      
    } catch (e) {
      debugPrint('Error playing mobile audio chunk: $e');
      _isPlayingStreamedAudio = false;
      onPlaybackStateChanged?.call(false);
    }
  }

  /// Convert raw PCM data to WAV format
  Uint8List _convertPcmToWav(Uint8List pcmData) {
    // WAV file format parameters
    const int sampleRate = 24000; // OpenAI uses 24kHz
    const int bitsPerSample = 16;
    const int channels = 1; // Mono
    const int bytesPerSample = bitsPerSample ~/ 8;
    
    final int dataSize = pcmData.length;
    final int fileSize = 36 + dataSize;
    
    // Create WAV header
    final ByteData header = ByteData(44);
    
    // RIFF header
    header.setUint8(0, 0x52); // 'R'
    header.setUint8(1, 0x49); // 'I'
    header.setUint8(2, 0x46); // 'F'
    header.setUint8(3, 0x46); // 'F'
    header.setUint32(4, fileSize, Endian.little);
    header.setUint8(8, 0x57);  // 'W'
    header.setUint8(9, 0x41);  // 'A'
    header.setUint8(10, 0x56); // 'V'
    header.setUint8(11, 0x45); // 'E'
    
    // fmt chunk
    header.setUint8(12, 0x66); // 'f'
    header.setUint8(13, 0x6D); // 'm'
    header.setUint8(14, 0x74); // 't'
    header.setUint8(15, 0x20); // ' '
    header.setUint32(16, 16, Endian.little); // fmt chunk size
    header.setUint16(20, 1, Endian.little);  // audio format (PCM)
    header.setUint16(22, channels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, sampleRate * channels * bytesPerSample, Endian.little); // byte rate
    header.setUint16(32, channels * bytesPerSample, Endian.little); // block align
    header.setUint16(34, bitsPerSample, Endian.little);
    
    // data chunk
    header.setUint8(36, 0x64); // 'd'
    header.setUint8(37, 0x61); // 'a'
    header.setUint8(38, 0x74); // 't'
    header.setUint8(39, 0x61); // 'a'
    header.setUint32(40, dataSize, Endian.little);
    
    // Combine header and PCM data
    final Uint8List wavData = Uint8List(44 + dataSize);
    wavData.setRange(0, 44, header.buffer.asUint8List());
    wavData.setRange(44, 44 + dataSize, pcmData);
    
    return wavData;
  }

  /// Play a regular audio file (for user recorded audio)
  Future<void> playAudio(String filePath) async {
    try {
      // Stop any currently playing audio
      await _audioPlayer.stop();
      
      // Play the new audio - handle both file paths and blob URLs
      if (kIsWeb && filePath.startsWith('blob:')) {
        // For web blob URLs
        await _audioPlayer.play(UrlSource(filePath));
      } else {
        // For mobile file paths
        await _audioPlayer.play(DeviceFileSource(filePath));
      }
      
    } catch (e) {
      debugPrint('Failed to play audio: $e');
    }
  }

  /// Stop all audio playback
  Future<void> stopAudio() async {
    try {
      await _audioPlayer.stop();
      _isPlayingStreamedAudio = false;
      onPlaybackStateChanged?.call(false);
    } catch (e) {
      debugPrint('Error stopping audio: $e');
    }
  }

  /// Get current playback state
  bool get isPlayingStreamedAudio => _isPlayingStreamedAudio;

  /// Get number of queued audio chunks
  int get queuedChunksCount => _streamedAudioChunks.length;

  /// Dispose of resources
  void dispose() {
    _audioPlayerSubscription?.cancel();
    _audioPlayer.dispose();
    _streamedAudioChunks.clear();
  }
}
