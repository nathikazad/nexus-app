import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nx_books/data/book/epub_progress_repository.dart';

class Remote implements EpubProgressRemote {
  Map<String, dynamic>? value;
  bool offline = false;
  Completer<void>? gate;
  int writes = 0;
  @override
  Future<Map<String, dynamic>?> load(int id) async {
    if (offline) throw StateError('offline');
    return value;
  }

  @override
  Future<void> save(int id, Map<String, dynamic> next) async {
    if (offline) throw StateError('offline');
    await gate?.future;
    value = next;
    writes++;
  }
}

Map<String, dynamic> position(int n) => {
  'location': {'version': 1, 'block': n, 'run': 0, 'character': 50},
  'saved_at': DateTime.utc(2026, 9, 12, 0, n).toIso8601String(),
};

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('offline progress survives reopening and syncs when online', () async {
    final remote = Remote()..offline = true;
    var repo = EpubProgressRepository(account: 'a', remote: remote);
    await repo.save(1, position(2));
    await expectLater(repo.flush(), throwsStateError);
    repo.dispose();
    repo = EpubProgressRepository(account: 'a', remote: remote);
    expect(await repo.load(1), position(2));
    remote.offline = false;
    await repo.flush();
    expect(remote.value, position(2));
    expect(remote.writes, 1);
    repo.dispose();
  });
  test('new page during an in-flight save stays pending', () async {
    final remote = Remote()..gate = Completer<void>();
    final repo = EpubProgressRepository(account: 'a', remote: remote);
    await repo.save(1, position(1));
    final flush = repo.flush();
    await Future<void>.delayed(Duration.zero);
    await repo.save(1, position(2));
    remote.gate!.complete();
    await flush;
    expect(await repo.load(1), position(2));
    await repo.flush();
    expect(remote.value, position(2));
    repo.dispose();
  });
  test(
    'newer remote wins over stale offline outbox; accounts stay separate',
    () async {
      final remote = Remote()..value = position(3);
      final repo = EpubProgressRepository(account: 'a', remote: remote);
      await repo.save(1, position(1));
      await repo.flush();
      expect(remote.writes, 0);
      expect(await repo.load(1), position(3));
      remote.offline = true;
      final other = EpubProgressRepository(account: 'b', remote: remote);
      expect(await other.load(1), isNull);
      repo.dispose();
      other.dispose();
    },
  );
}
