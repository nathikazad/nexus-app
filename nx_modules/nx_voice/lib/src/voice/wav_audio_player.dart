import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_sound/flutter_sound.dart';
import 'package:logger/logger.dart';
import 'package:opus_dart/opus_dart.dart';

import 'opus_codec.dart';

class NxWavAudioPlayer {
  NxWavAudioPlayer({
    this.sampleRate = 16000,
    this.channels = 1,
    this.bitsPerSample = 16,
    this.chunksPerBatch = 40,
    this.batchTimeout = const Duration(milliseconds: 200),
    this.bufferSize = 8192,
  });

  final int sampleRate;
  final int channels;
  final int bitsPerSample;
  final int chunksPerBatch;
  final Duration batchTimeout;
  final int bufferSize;

  final FlutterSoundPlayer _player = FlutterSoundPlayer(logLevel: Level.off);
  final Queue<Uint8List> _pcmQueue = Queue<Uint8List>();
  SimpleOpusDecoder? _decoder;
  Future<void>? _startFuture;
  bool _playerOpen = false;
  bool _streamStarted = false;
  bool _isFeeding = false;
  bool _isPlaying = false;
  Future<void> _opusDecodeChain = Future<void>.value();

  void Function(bool isPlaying)? onPlaybackStateChanged;

  Future<void> addOpusPacket(Uint8List opus) {
    final packet = Uint8List.fromList(opus);
    final next = _opusDecodeChain.then((_) => _decodeAndAddOpusPacket(packet));
    _opusDecodeChain = next.catchError((Object error) {
      debugPrint('[nx_voice player] opus decode error: $error');
    });
    return next;
  }

  Future<void> _decodeAndAddOpusPacket(Uint8List opus) async {
    await NxOpusCodec.initialize();
    _decoder ??= SimpleOpusDecoder(sampleRate: sampleRate, channels: channels);
    final samples = _decoder!.decode(input: opus);
    await addPcmChunk(Uint8List.sublistView(samples));
  }

  Future<void> addPcmChunk(Uint8List pcm) async {
    if (pcm.isEmpty) return;
    _pcmQueue.add(Uint8List.fromList(pcm));
    await _ensureStarted();
    _markPlaying(true);
    unawaited(_drainQueue());
  }

  Future<void> flush() async {
    await _opusDecodeChain;
    await _drainQueue();
    _resetDecoder();
  }

  Future<void> stop() async {
    _pcmQueue.clear();
    _isFeeding = false;
    _opusDecodeChain = Future<void>.value();
    _resetDecoder();
    if (_streamStarted || _playerOpen) {
      try {
        await _player.stopPlayer();
      } catch (error) {
        debugPrint('[nx_voice player] stopPlayer error: $error');
      }
    }
    _streamStarted = false;
    _markPlaying(false);
  }

  Future<void> dispose() async {
    await stop();
    if (_playerOpen) {
      try {
        await _player.closePlayer();
      } catch (error) {
        debugPrint('[nx_voice player] closePlayer error: $error');
      }
      _playerOpen = false;
    }
  }

  Future<void> _ensureStarted() {
    return _startFuture ??= _startStream();
  }

  Future<void> _startStream() async {
    try {
      if (!_playerOpen) {
        await _player.openPlayer();
        _playerOpen = true;
      }
      if (!_streamStarted) {
        await _player.startPlayerFromStream(
          codec: Codec.pcm16,
          interleaved: true,
          numChannels: channels,
          sampleRate: sampleRate,
          bufferSize: bufferSize,
          onBufferUnderflow: () {
            if (_pcmQueue.isEmpty && !_isFeeding) {
              _markPlaying(false);
            }
          },
        );
        _streamStarted = true;
      }
    } finally {
      _startFuture = null;
    }
  }

  Future<void> _drainQueue() async {
    if (_isFeeding) return;
    _isFeeding = true;
    try {
      await _ensureStarted();
      while (_pcmQueue.isNotEmpty && _streamStarted) {
        final pcm = _pcmQueue.removeFirst();
        await _player.feedUint8FromStream(pcm);
      }
    } catch (error) {
      debugPrint('[nx_voice player] feed error: $error');
      _markPlaying(false);
    } finally {
      _isFeeding = false;
      if (_pcmQueue.isNotEmpty) {
        unawaited(_drainQueue());
      }
    }
  }

  void _markPlaying(bool value) {
    if (_isPlaying == value) return;
    _isPlaying = value;
    onPlaybackStateChanged?.call(value);
  }

  void _resetDecoder() {
    _decoder?.destroy();
    _decoder = null;
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
