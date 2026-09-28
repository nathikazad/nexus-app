import 'dart:async';
import 'dart:typed_data';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_offline/nx_offline.dart';
import 'audio_asset.dart';
import 'audio_store.dart';

final class AudioDownloadProgress {
  const AudioDownloadProgress({
    this.total = 0,
    this.ready = 0,
    this.failed = 0,
    this.running = false,
  });
  final int total, ready, failed;
  final bool running;
}

final class OfflineCardAudioRepository implements CardAudioRepository {
  OfflineCardAudioRepository({required this.remote, required this.store});
  final CardAudioRepository? remote;
  final AudioStore store;
  final _queue = AttachmentQueue();
  final _changes = StreamController<AudioDownloadProgress>.broadcast();
  AudioDownloadProgress progress = const AudioDownloadProgress();
  Stream<AudioDownloadProgress> get changes => _changes.stream;
  Map<String, AudioAsset> _assets = {};
  bool _closed = false;
  int _generation = 0;

  void _report(AudioDownloadProgress value) {
    if (_closed) return;
    progress = value;
    _changes.add(value);
  }

  @override
  Future<Uint8List> fetch(String audioUrl) => _download(
    _assets[audioUrl] ?? AudioAsset.fromUrl(audioUrl),
    foreground: true,
  );
  Future<Uint8List> _download(AudioAsset asset, {bool foreground = false}) =>
      _queue.run(asset.url, () async {
        if (_closed) throw StateError('Audio session closed');
        asset.validate();
        final local = await store.read(asset);
        if (local != null) return local;
        final source = remote;
        if (source == null) throw StateError('Audio has not been downloaded');
        final bytes = await source
            .fetch(asset.url)
            .timeout(const Duration(seconds: 45));
        if (_closed) throw StateError('Audio session closed');
        await store.write(asset, bytes);
        if (foreground) await store.flush();
        return bytes;
      }, foreground: foreground);

  Future<void> sync(
    List<AudioAsset> assets, {
    required bool Function() canClean,
  }) async {
    final generation = ++_generation;
    _assets = {for (final asset in assets) asset.url: asset};
    final unique = {for (final asset in assets) asset.url: asset};
    var ready = 0, failed = 0;
    void report(bool running) {
      if (generation == _generation) {
        _report(
          AudioDownloadProgress(
            total: unique.length,
            ready: ready,
            failed: failed,
            running: running,
          ),
        );
      }
    }

    // Check disk metadata silently. Only missing/changed audio enters the
    // download queue; a normal sync never reopens verified recordings.
    final pending = <AudioAsset>[];
    for (final asset in unique.values) {
      if (_closed || generation != _generation) return;
      try {
        if (await store.contains(asset)) {
          ready++;
        } else {
          pending.add(asset);
        }
      } catch (_) {
        failed++;
      }
    }
    if (_closed || generation != _generation) return;
    report(pending.isNotEmpty);
    await Future.wait([
      for (final asset in pending)
        () async {
          try {
            await _download(asset);
            ready++;
          } catch (_) {
            failed++;
          }
          report(true);
        }(),
    ]);
    // Only a fully verified, still-current library may remove old versions.
    if (!_closed && generation == _generation && failed == 0 && canClean()) {
      await store.retain(unique.values.map((a) => a.sha256).toSet());
    }
    await store.flush();
    report(false);
  }

  Future<void> close() async {
    _closed = true;
    await _queue.close();
    await _changes.close();
  }
}
