import 'dart:io';
import 'package:nx_cards/audio/audio_store.dart';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/audio/audio_asset.dart';
import 'package:nx_cards/audio/audio_store_native.dart';
import 'package:nx_cards/audio/offline_card_audio.dart';
import 'package:nx_cards/browser/browser.dart';

AudioAsset asset(List<int> data) {
  final hash = sha256.convert(data).toString();
  return AudioAsset(
    '/nx_cards/assets/audio/file?name=1-$hash.mp3',
    hash,
    data.length,
  );
}

class Remote implements CardAudioRepository {
  Remote(this.data);
  final Map<String, Uint8List> data;
  int requests = 0;
  @override
  Future<Uint8List> fetch(String url) async {
    requests++;
    final bytes = data[url];
    if (bytes == null) throw StateError('Offline');
    return bytes;
  }
}

void main() {
  late Directory root;
  late DirectoryAudioStore store;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('cards-audio-test-');
    store = DirectoryAudioStore(root);
  });
  tearDown(() async => root.delete(recursive: true));

  test(
    'download survives repository restart and works with no network',
    () async {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final a = asset(bytes);
      final remote = Remote({a.url: bytes});
      final repo = OfflineCardAudioRepository(remote: remote, store: store);
      await repo.sync([a], canClean: () => true);
      expect(repo.progress.ready, 1);
      expect(remote.requests, 1);
      await repo.sync([a], canClean: () => true);
      expect(remote.requests, 1);
      await repo.close();
      final offline = OfflineCardAudioRepository(
        remote: null,
        store: DirectoryAudioStore(root),
      );
      expect(await offline.fetch(a.url), bytes);
      await offline.close();
    },
  );
  test(
    'unchanged sync and restart stay silent and do not load audio bytes',
    () async {
      final bytes = Uint8List.fromList([7, 8, 9]);
      final a = asset(bytes);
      final remote = Remote({a.url: bytes});
      final initial = OfflineCardAudioRepository(remote: remote, store: store);
      await initial.sync([a], canClean: () => true);
      await initial.close();
      final index = File('${root.path}/verified.json');
      final before = await index.readAsString();
      final modified = (await index.stat()).modified;
      final checked = MetadataOnlyStore(DirectoryAudioStore(root));
      final repo = OfflineCardAudioRepository(remote: remote, store: checked);
      final reports = <AudioDownloadProgress>[];
      final subscription = repo.changes.listen(reports.add);
      await repo.sync([a], canClean: () => true);
      await repo.sync([a], canClean: () => true);
      await Future<void>.delayed(Duration.zero);
      expect(remote.requests, 1);
      expect(checked.reads, 0);
      expect(reports.any((p) => p.running), isFalse);
      expect(await index.readAsString(), before);
      expect((await index.stat()).modified, modified);
      await subscription.cancel();
      await repo.close();
    },
  );
  test(
    'deleted file is downloaded again even with a saved verification index',
    () async {
      final bytes = Uint8List.fromList([4, 5, 6]);
      final a = asset(bytes);
      final remote = Remote({a.url: bytes});
      final repo = OfflineCardAudioRepository(remote: remote, store: store);
      await repo.sync([a], canClean: () => true);
      await File('${root.path}/${a.sha256}.mp3').delete();
      await repo.sync([a], canClean: () => true);
      expect(remote.requests, 2);
      expect(await store.read(a), bytes);
      final file = File('${root.path}/${a.sha256}.mp3');
      await file.writeAsBytes([0, 0, 0]);
      await file.setLastModified(DateTime.utc(2020));
      await repo.sync([a], canClean: () => true);
      expect(remote.requests, 3);
      expect(await store.read(a), bytes);
      await repo.close();
    },
  );
  test(
    'failed replacement preserves old audio, retry verifies then collects old file',
    () async {
      final old = Uint8List.fromList([1, 2]);
      final fresh = Uint8List.fromList([3, 4]);
      final a = asset(old), b = asset(fresh);
      await store.write(a, old);
      final remote = Remote({b.url: old}); // wrong bytes at the new URL
      final repo = OfflineCardAudioRepository(remote: remote, store: store);
      await repo.sync([b], canClean: () => true);
      expect(repo.progress.failed, 1);
      expect(await store.read(b), isNull);
      expect(await store.read(a), old);
      remote.data[b.url] = fresh;
      await repo.sync([b], canClean: () => true);
      expect(repo.progress.failed, 0);
      expect(await store.read(b), fresh);
      expect(await store.read(a), isNull);
      await repo.close();
    },
  );
  test(
    'a corrupt local file is repaired and stale library cannot clean',
    () async {
      final bytes = Uint8List.fromList([5, 6, 7]);
      final a = asset(bytes);
      final other = asset([9]);
      await store.write(other, Uint8List.fromList([9]));
      await File('${root.path}/${a.sha256}.mp3').writeAsBytes([0, 0, 0]);
      final remote = Remote({a.url: bytes});
      final repo = OfflineCardAudioRepository(remote: remote, store: store);
      await repo.sync([a], canClean: () => false);
      expect(remote.requests, 1);
      expect(await store.read(a), bytes);
      expect(await store.read(other), isNotNull);
      await repo.close();
    },
  );
  test('different account directories never share downloads', () async {
    final a = asset([1]);
    await store.write(a, Uint8List.fromList([1]));
    final other = DirectoryAudioStore(Directory('${root.path}/other-account'));
    expect(await other.read(a), isNull);
  });
  test(
    'bad metadata is counted as pending without blocking valid recordings',
    () async {
      final a = asset([1]);
      final repo = OfflineCardAudioRepository(
        remote: Remote({
          a.url: Uint8List.fromList([1]),
        }),
        store: store,
      );
      await repo.sync([
        a,
        const AudioAsset('/old.mp3', '', null),
      ], canClean: () => true);
      expect(repo.progress.total, 2);
      expect(repo.progress.ready, 1);
      expect(repo.progress.failed, 1);
      await repo.close();
    },
  );
}

class MetadataOnlyStore implements AudioStore {
  MetadataOnlyStore(this.delegate);
  final AudioStore delegate;
  int reads = 0;
  @override
  Future<bool> contains(AudioAsset asset) => delegate.contains(asset);
  @override
  Future<void> flush() => delegate.flush();
  @override
  Future<Uint8List?> read(AudioAsset asset) {
    reads++;
    return delegate.read(asset);
  }

  @override
  Future<void> write(AudioAsset asset, Uint8List bytes) =>
      delegate.write(asset, bytes);
  @override
  Future<void> retain(Set<String> hashes) => delegate.retain(hashes);
}
