import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nx_books/data/book/epub_progress_repository.dart';

class Remote implements EpubProgressRemote {
  Map<String, dynamic>? value;
  bool offline = false;
  Completer<void>? gate;
  int writes = 0;
  int reads = 0;
  @override
  Future<Map<String, dynamic>?> load(int id) async {
    reads++;
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
  test('web progress goes to the server without a persistent outbox', () async {
    SharedPreferences.setMockInitialValues({});
    final remote = Remote();
    final repository = EpubProgressRepository(
      account: 'web',
      remote: remote,
      persistData: false,
    );
    addTearDown(repository.dispose);
    await repository.save(1, position(1));
    expect(await repository.load(1), position(1));
    await repository.flush();
    expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
    remote.offline = true;
    await expectLater(repository.save(1, position(2)), throwsStateError);
  });

  test('nested progress preserves every attachment metadata field', () {
    final file = {
      'link': '/books/book.epub',
      'sha256': 'abc',
      'size': 123,
      'custom': {'keep': true},
      'reading_position': {'old': true},
    };
    final progress = {...position(2), 'sha256': 'abc'};
    final updated = bookFileWithPosition(file, progress);
    expect(updated['reading_position'], progress);
    expect(
      {...updated}..remove('reading_position'),
      {...file}..remove('reading_position'),
    );
    expect(file['reading_position'], {'old': true});
    expect(
      () => bookFileWithPosition(file, {...progress, 'sha256': 'different'}),
      throwsStateError,
    );
    expect(epubProgressAttribute, 'book_file');
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'source links use local preferences without a network request',
    () async {
      final remote = Remote()..value = position(1);
      final repo = EpubProgressRepository(account: 'a', remote: remote);
      expect(await repo.load(1), position(1));
      expect(remote.reads, 1);
      remote.value = position(2);
      expect(await repo.load(1, refreshRemote: false), position(1));
      expect(await repo.load(2, refreshRemote: false), isNull);
      expect(remote.reads, 1);
      repo.dispose();
    },
  );
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
