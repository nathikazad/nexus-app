import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/data/audio/cached_card_audio_repository.dart';
import 'package:nx_cards/domain/card/card_audio_repository.dart';

void main() {
  test(
    'returns persisted audio without calling the remote repository',
    () async {
      final cache = _MemoryAudioCache()
        ..values['/cards/audio/1/11.mp3'] = Uint8List.fromList(<int>[1, 2, 3]);
      final remote = _FakeAudioRepository(Uint8List.fromList(<int>[9]));
      final repository = CachedCardAudioRepository(
        remote: remote,
        cache: cache,
      );

      final bytes = await repository.fetch('/cards/audio/1/11.mp3');

      expect(bytes, <int>[1, 2, 3]);
      expect(remote.calls, 0);
    },
  );

  test('downloads once and persists bytes for offline replay', () async {
    final cache = _MemoryAudioCache();
    final remote = _FakeAudioRepository(Uint8List.fromList(<int>[4, 5, 6]));
    final repository = CachedCardAudioRepository(remote: remote, cache: cache);

    expect(await repository.fetch('/audio.mp3'), <int>[4, 5, 6]);
    expect(await repository.fetch('/audio.mp3'), <int>[4, 5, 6]);
    expect(remote.calls, 1);
  });

  test('cache write failure does not discard downloaded audio', () async {
    final remote = _FakeAudioRepository(Uint8List.fromList(<int>[7, 8, 9]));
    final repository = CachedCardAudioRepository(
      remote: remote,
      cache: _FailingAudioCache(),
    );

    expect(await repository.fetch('/audio.mp3'), <int>[7, 8, 9]);
    expect(remote.calls, 1);
  });
}

final class _MemoryAudioCache implements CardAudioByteCache {
  final Map<String, Uint8List> values = <String, Uint8List>{};

  @override
  Future<Uint8List?> read(String key) async => values[key];

  @override
  Future<void> write(String key, Uint8List bytes) async {
    values[key] = bytes;
  }
}

final class _FakeAudioRepository implements CardAudioRepository {
  _FakeAudioRepository(this.bytes);

  final Uint8List bytes;
  int calls = 0;

  @override
  Future<Uint8List> fetch(String audioUrl) async {
    calls++;
    return bytes;
  }
}

final class _FailingAudioCache implements CardAudioByteCache {
  @override
  Future<Uint8List?> read(String key) async => null;

  @override
  Future<void> write(String key, Uint8List bytes) =>
      Future<void>.error(StateError('disk unavailable'));
}
