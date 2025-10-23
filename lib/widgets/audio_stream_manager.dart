import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

class AudioStreamManager {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final List<Uint8List> _streamedAudioChunks = [];
  final Queue<String> _batchedAudioFiles = Queue<String>(); // Queue of batched WAV files
  bool _isPlayingStreamedAudio = false;
  StreamSubscription? _audioPlayerSubscription;
  bool _speakerEnabled = false;
  
  // Batching settings
  static const int _chunksPerBatch = 20; // Accumulate 20 chunks before creating WAV file
  static const int _batchTimeoutMs = 200; // Create batch if no new data for 200ms
  List<Uint8List> _currentBatch = []; // Current batch being accumulated
  Timer? _batchTimeoutTimer; // Timer for batch timeout
  
  // Callback for when audio playback state changes
  Function(bool)? onPlaybackStateChanged;

  AudioStreamManager();

  /// Add audio data to the streaming queue (with batching)
  Future<void> playStreamedAudio(Uint8List audioData) async {
    if (!_speakerEnabled) {
      return;
    }
    try {
      // Cancel existing timeout timer
      _batchTimeoutTimer?.cancel();
      
      // Add chunk to current batch
      _currentBatch.add(audioData);
      debugPrint('📦 Added chunk to batch: ${_currentBatch.length}/${_chunksPerBatch} chunks');
      
      // Check if batch is complete
      if (_currentBatch.length >= _chunksPerBatch) {
        await _createBatchedWavFile();
      } else {
        // Set timeout timer for remaining chunks
        _batchTimeoutTimer = Timer(Duration(milliseconds: _batchTimeoutMs), () async {
          if (_currentBatch.isNotEmpty) {
            debugPrint('⏰ Batch timeout (${_batchTimeoutMs}ms) - creating batch with ${_currentBatch.length} chunks');
            await _createBatchedWavFile();
          }
        });
      }
      
      // If we're not already playing streamed audio, start playing
      if (!_isPlayingStreamedAudio && _batchedAudioFiles.isNotEmpty) {
        _isPlayingStreamedAudio = true;
        onPlaybackStateChanged?.call(true);
        _setupAudioPlayerListener();
        _playNextBatchedFile();
      }
    } catch (e) {
      debugPrint('Error handling streamed audio: $e');
    }
  }

  /// Create a batched WAV file from accumulated chunks
  Future<void> _createBatchedWavFile() async {
    if (_currentBatch.isEmpty) return;
    
    // Cancel timeout timer since we're creating the batch
    _batchTimeoutTimer?.cancel();
    
    try {
      // Concatenate all PCM chunks in the batch
      int totalLength = 0;
      for (final chunk in _currentBatch) {
        totalLength += chunk.length;
      }
      
      final Uint8List concatenatedPcm = Uint8List(totalLength);
      int offset = 0;
      for (final chunk in _currentBatch) {
        concatenatedPcm.setRange(offset, offset + chunk.length, chunk);
        offset += chunk.length;
      }
      
      // Convert to WAV
      final wavData = _convertPcmToWav(concatenatedPcm);
      
      // Create file or data URL
      String audioFile;
      if (kIsWeb) {
        // For web: create data URL
        audioFile = Uri.dataFromBytes(wavData, mimeType: 'audio/wav').toString();
      } else {
        // For mobile: create temp file
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/batched_audio_${DateTime.now().millisecondsSinceEpoch}.wav');
        await tempFile.writeAsBytes(wavData);
        audioFile = tempFile.path;
      }
      
      // Add to queue
      _batchedAudioFiles.add(audioFile);
      debugPrint('🎵 Created batched WAV file: ${_currentBatch.length} chunks -> ${(wavData.length / 1024).toStringAsFixed(1)} KB');
      
      // Clear current batch
      _currentBatch.clear();
      
      // Start playback if not already playing
      if (!_isPlayingStreamedAudio && _batchedAudioFiles.isNotEmpty) {
        _isPlayingStreamedAudio = true;
        onPlaybackStateChanged?.call(true);
        _setupAudioPlayerListener();
        _playNextBatchedFile();
      }
      
    } catch (e) {
      debugPrint('Error creating batched WAV file: $e');
      _currentBatch.clear(); // Clear batch even on error
    }
  }

  void setSpeakerEnabled(bool enabled) {
    _speakerEnabled = enabled;
    if (!enabled) {
      stopAudio();
    }
  }

  /// Set up a single listener for audio completion
  void _setupAudioPlayerListener() {
    // Cancel any existing listener
    _audioPlayerSubscription?.cancel();
    
    // Set up a single listener for audio completion
    _audioPlayerSubscription = _audioPlayer.onPlayerComplete.listen((_) {
      // Play next batched file if available
      if (_batchedAudioFiles.isNotEmpty) {
        _playNextBatchedFile();
      } else {
        _isPlayingStreamedAudio = false;
        onPlaybackStateChanged?.call(false);
        _audioPlayerSubscription?.cancel();
      }
    });
  }

  /// Play the next batched audio file in the queue
  Future<void> _playNextBatchedFile() async {
    if (_batchedAudioFiles.isEmpty) {
      _isPlayingStreamedAudio = false;
      onPlaybackStateChanged?.call(false);
      _audioPlayerSubscription?.cancel();
      return;
    }

    try {
      // Take the first batched file
      final audioFile = _batchedAudioFiles.removeFirst();
      debugPrint('🎵 Playing batched file, remaining files: ${_batchedAudioFiles.length}');
      
      // Play the audio file
      if (kIsWeb && audioFile.startsWith('data:')) {
        // For web data URLs
        await _audioPlayer.play(UrlSource(audioFile));
      } else {
        // For mobile file paths
        await _audioPlayer.play(DeviceFileSource(audioFile));
      }
      
    } catch (e) {
      debugPrint('Error playing batched audio file: $e');
      _isPlayingStreamedAudio = false;
      onPlaybackStateChanged?.call(false);
      _audioPlayerSubscription?.cancel();
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
      _streamedAudioChunks.clear();
      _batchedAudioFiles.clear();
      _currentBatch.clear();
      _batchTimeoutTimer?.cancel();
    } catch (e) {
      debugPrint('Error stopping audio: $e');
    }
  }

  /// Flush any remaining chunks in the current batch
  Future<void> flushRemainingChunks() async {
    if (_currentBatch.isNotEmpty) {
      debugPrint('🔄 Flushing remaining ${_currentBatch.length} chunks...');
      await _createBatchedWavFile();
    }
  }

  /// Get current playback state
  bool get isPlayingStreamedAudio => _isPlayingStreamedAudio;

  /// Get number of queued batched files
  int get queuedFilesCount => _batchedAudioFiles.length;
  
  /// Get number of chunks in current batch
  int get currentBatchSize => _currentBatch.length;

  /// Dispose of resources
  void dispose() {
    _audioPlayerSubscription?.cancel();
    _audioPlayer.dispose();
    _streamedAudioChunks.clear();
    _batchedAudioFiles.clear();
    _currentBatch.clear();
    _batchTimeoutTimer?.cancel();
  }
}
