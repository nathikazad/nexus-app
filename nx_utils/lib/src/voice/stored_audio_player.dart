import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

import 'opus_codec.dart';
import 'stored_audio_file_stub.dart'
    if (dart.library.io) 'stored_audio_file_io.dart';
import 'stored_opus_audio.dart';
import 'wav_audio_player.dart';

class NxStoredAudioPlayer {
  NxStoredAudioPlayer({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client(),
        _ownsHttpClient = httpClient == null;

  final FlutterSoundPlayer _player = FlutterSoundPlayer(logLevel: Level.off);
  final http.Client _httpClient;
  final bool _ownsHttpClient;
  StreamSubscription<PlaybackDisposition>? _progressSubscription;
  bool _open = false;
  bool _sourceStarted = false;
  bool _playing = false;
  bool _loading = false;
  String? _loadedUrl;
  Duration? _loadedDuration;
  Uint8List? _loadedAudio;
  String? _loadedFilePath;

  void Function(Duration position, Duration duration)? onProgress;
  void Function(bool playing)? onPlaybackStateChanged;
  void Function(bool loading)? onLoadingStateChanged;
  VoidCallback? onComplete;

  bool get isPlaying => _playing;
  bool get isLoading => _loading;

  Future<void> play(
    String url, {
    Duration? startAt,
    Duration? duration,
  }) async {
    if (_loading) return;
    await _ensureOpen();
    if (!_sourceStarted) {
      _markLoading(true);
      try {
        final audio = await _audioFor(url, duration: duration);
        final filePath = await _fileForAudio(audio);
        await _player.startPlayer(
          fromURI: filePath,
          fromDataBuffer: filePath == null ? audio : null,
          codec: Codec.pcm16WAV,
          whenFinished: () {
            _sourceStarted = false;
            _markPlaying(false);
            onComplete?.call();
          },
        );
        _sourceStarted = true;
        _markPlaying(true);
        if (startAt != null && startAt > Duration.zero) {
          try {
            await _player.seekToPlayer(startAt);
          } catch (error) {
            debugPrint(
              '[nx_utils stored audio] initial seek failed; '
              'continuing playback: $error',
            );
          }
        }
      } finally {
        _markLoading(false);
      }
    } else {
      await _player.resumePlayer();
    }
    _markPlaying(true);
  }

  Future<void> pause() async {
    if (!_sourceStarted || !_playing) return;
    await _player.pausePlayer();
    _markPlaying(false);
  }

  Future<void> seek(Duration position) async {
    if (!_sourceStarted) return;
    await _player.seekToPlayer(position);
  }

  Future<void> stop() async {
    if (_sourceStarted || _open) {
      await _player.stopPlayer();
    }
    _sourceStarted = false;
    _markPlaying(false);
  }

  Future<void> dispose() async {
    await _progressSubscription?.cancel();
    _progressSubscription = null;
    await stop();
    if (_open) {
      await _player.closePlayer();
      _open = false;
    }
    _loadedAudio = null;
    _loadedUrl = null;
    _loadedDuration = null;
    await deleteStoredAudioFile(_loadedFilePath);
    _loadedFilePath = null;
    if (_ownsHttpClient) _httpClient.close();
  }

  Future<Uint8List> _audioFor(String url, {Duration? duration}) async {
    if (_loadedUrl == url &&
        _loadedDuration == duration &&
        _loadedAudio != null) {
      return _loadedAudio!;
    }
    final request = http.Request('GET', Uri.parse(url));
    final response = await _httpClient.send(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Audio download failed (${response.statusCode}).');
    }
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in response.stream) {
      bytes.add(chunk);
    }
    final downloaded = bytes.takeBytes();
    if (downloaded.isEmpty) throw StateError('Downloaded audio is empty.');
    final storedOpus = NxStoredOpusAudio.tryParse(downloaded);
    final audio = storedOpus == null
        ? downloaded
        : await _decodeOpus(storedOpus, duration: duration);
    await deleteStoredAudioFile(_loadedFilePath);
    _loadedFilePath = null;
    _loadedUrl = url;
    _loadedDuration = duration;
    _loadedAudio = audio;
    return audio;
  }

  Future<String?> _fileForAudio(Uint8List audio) async {
    final existing = _loadedFilePath;
    if (existing != null) return existing;
    final path = await writeStoredAudioFile(audio);
    _loadedFilePath = path;
    return path;
  }

  Future<Uint8List> _decodeOpus(
    NxStoredOpusAudio audio, {
    Duration? duration,
  }) async {
    var pcm = await NxOpusCodec.decodeToPcm16(
      audio.packets,
      sampleRate: audio.sampleRate,
      channels: 1,
    );
    if (duration != null && duration > Duration.zero) {
      final requestedBytes = (duration.inMicroseconds * audio.sampleRate * 2) ~/
          Duration.microsecondsPerSecond;
      final alignedBytes = requestedBytes - (requestedBytes % 2);
      if (alignedBytes < pcm.length) {
        pcm = Uint8List.sublistView(pcm, 0, alignedBytes);
      }
    }
    return NxWavAudioPlayer.pcmToWav(pcm, sampleRate: audio.sampleRate);
  }

  Future<void> _ensureOpen() async {
    if (_open) return;
    await _player.openPlayer();
    await _player.setVolume(1);
    await _player.setSubscriptionDuration(const Duration(milliseconds: 120));
    _progressSubscription = _player.onProgress?.listen((event) {
      onProgress?.call(event.position, event.duration);
    });
    _open = true;
  }

  void _markPlaying(bool value) {
    if (_playing == value) return;
    _playing = value;
    onPlaybackStateChanged?.call(value);
  }

  void _markLoading(bool value) {
    if (_loading == value) return;
    _loading = value;
    onLoadingStateChanged?.call(value);
  }
}

typedef VoidCallback = void Function();
