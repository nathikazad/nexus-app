import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'opus_codec.dart';

class NxWavAudioPlayer {
  NxWavAudioPlayer({
    this.sampleRate = 16000,
    this.channels = 1,
    this.bitsPerSample = 16,
    this.chunksPerBatch = 20,
    this.batchTimeout = const Duration(milliseconds: 200),
  });

  final int sampleRate;
  final int channels;
  final int bitsPerSample;
  final int chunksPerBatch;
  final Duration batchTimeout;

  final AudioPlayer _audioPlayer = AudioPlayer();
  final Queue<String> _queuedFiles = Queue<String>();
  final List<Uint8List> _currentBatch = [];
  StreamSubscription<void>? _completeSubscription;
  Timer? _batchTimer;
  bool _isPlaying = false;
  bool _isCreatingBatch = false;
  bool _isTransitioningPlayback = false;

  void Function(bool isPlaying)? onPlaybackStateChanged;

  Future<void> addOpusPacket(Uint8List opus) async {
    final pcm = await NxOpusCodec.decodeToPcm16(
      [opus],
      sampleRate: sampleRate,
      channels: channels,
    );
    await addPcmChunk(pcm);
  }

  Future<void> addPcmChunk(Uint8List pcm) async {
    _batchTimer?.cancel();
    _currentBatch.add(pcm);
    if (_currentBatch.length >= chunksPerBatch) {
      await _createBatch();
    } else {
      _batchTimer = Timer(batchTimeout, () {
        unawaited(_createBatch());
      });
    }

    if (!_isPlaying && _queuedFiles.isNotEmpty) {
      _startPlayback();
    }
  }

  Future<void> flush() async {
    _batchTimer?.cancel();
    await _createBatch();
    if (!_isPlaying && _queuedFiles.isNotEmpty) {
      _startPlayback();
    }
  }

  Future<void> stop() async {
    _batchTimer?.cancel();
    await _audioPlayer.stop();
    _queuedFiles.clear();
    _currentBatch.clear();
    _isPlaying = false;
    onPlaybackStateChanged?.call(false);
  }

  Future<void> dispose() async {
    await stop();
    await _completeSubscription?.cancel();
    await _audioPlayer.dispose();
  }

  Future<void> _createBatch() async {
    if (_isCreatingBatch || _currentBatch.isEmpty) return;
    _isCreatingBatch = true;
    _batchTimer?.cancel();

    try {
      final batch = List<Uint8List>.from(_currentBatch);
      _currentBatch.clear();
      final total = batch.fold<int>(0, (sum, chunk) => sum + chunk.length);
      final pcm = Uint8List(total);
      var offset = 0;
      for (final chunk in batch) {
        pcm.setRange(offset, offset + chunk.length, chunk);
        offset += chunk.length;
      }

      final wav = pcmToWav(
        pcm,
        sampleRate: sampleRate,
        channels: channels,
        bitsPerSample: bitsPerSample,
      );
      String source;
      if (kIsWeb) {
        source = Uri.dataFromBytes(wav, mimeType: 'audio/wav').toString();
      } else {
        final dir = await getTemporaryDirectory();
        final file = File(
          '${dir.path}/nx_voice_${DateTime.now().microsecondsSinceEpoch}.wav',
        );
        await file.writeAsBytes(wav);
        source = file.path;
      }
      _queuedFiles.add(source);
    } finally {
      _isCreatingBatch = false;
    }
  }

  void _startPlayback() {
    _isPlaying = true;
    onPlaybackStateChanged?.call(true);
    _completeSubscription?.cancel();
    _completeSubscription = _audioPlayer.onPlayerComplete.listen((_) {
      if (_isTransitioningPlayback) return;
      if (_queuedFiles.isNotEmpty) {
        Future<void>.delayed(const Duration(milliseconds: 50), _playNext);
      } else {
        _isPlaying = false;
        onPlaybackStateChanged?.call(false);
      }
    });
    unawaited(_playNext());
  }

  Future<void> _playNext() async {
    if (_queuedFiles.isEmpty) {
      _isPlaying = false;
      onPlaybackStateChanged?.call(false);
      return;
    }

    final source = _queuedFiles.removeFirst();
    _isTransitioningPlayback = true;
    try {
      if (kIsWeb && source.startsWith('data:')) {
        await _audioPlayer.play(UrlSource(source));
      } else {
        await _audioPlayer.play(DeviceFileSource(source));
      }
    } finally {
      _isTransitioningPlayback = false;
    }
  }

  static Uint8List pcmToWav(
    Uint8List pcmData, {
    int sampleRate = 16000,
    int channels = 1,
    int bitsPerSample = 16,
  }) {
    final bytesPerSample = bitsPerSample ~/ 8;
    final dataSize = pcmData.length;
    final fileSize = 36 + dataSize;
    final header = ByteData(44);

    header.setUint8(0, 0x52);
    header.setUint8(1, 0x49);
    header.setUint8(2, 0x46);
    header.setUint8(3, 0x46);
    header.setUint32(4, fileSize, Endian.little);
    header.setUint8(8, 0x57);
    header.setUint8(9, 0x41);
    header.setUint8(10, 0x56);
    header.setUint8(11, 0x45);
    header.setUint8(12, 0x66);
    header.setUint8(13, 0x6D);
    header.setUint8(14, 0x74);
    header.setUint8(15, 0x20);
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, channels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(
      28,
      sampleRate * channels * bytesPerSample,
      Endian.little,
    );
    header.setUint16(32, channels * bytesPerSample, Endian.little);
    header.setUint16(34, bitsPerSample, Endian.little);
    header.setUint8(36, 0x64);
    header.setUint8(37, 0x61);
    header.setUint8(38, 0x74);
    header.setUint8(39, 0x61);
    header.setUint32(40, dataSize, Endian.little);

    final wav = Uint8List(44 + dataSize);
    wav.setRange(0, 44, header.buffer.asUint8List());
    wav.setRange(44, 44 + dataSize, pcmData);
    return wav;
  }
}
