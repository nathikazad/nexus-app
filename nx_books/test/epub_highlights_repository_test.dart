import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nx_books/data/book/epub_highlights_repository.dart';

class Remote implements EpubHighlightsRemote {
  Map<String, dynamic> records = {};
  bool offline = false;
  Completer<void>? gate;
  @override
  Future<Map<String, dynamic>> load(int id) async {
    if (offline) throw StateError('offline');
    return {...records};
  }

  @override
  Future<void> save(int id, Map<String, dynamic> next) async {
    if (offline) throw StateError('offline');
    await gate?.future;
    records = mergeEpubHighlights(records, next);
  }
}

Map<String, dynamic> record(String id, int time, {bool deleted = false}) => {
  'id': id,
  'updated_at': time,
  'revision': '$time',
  'deleted': deleted,
  'sha256': 'file-a',
  'text': 'Selected words',
  'color': 0xffffe082,
  'start': {'version': 1, 'block': 0, 'run': 0, 'character': 0},
  'end': {'version': 1, 'block': 0, 'run': 0, 'character': 8},
};
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'offline edits survive reopening and merge additions from two devices',
    () async {
      final remote = Remote()..offline = true;
      var a = EpubHighlightsRepository(account: 'device-a', remote: remote);
      await a.save(42, record('a', 1));
      await a.flush();
      a.dispose();
      a = EpubHighlightsRepository(account: 'device-a', remote: remote);
      addTearDown(a.dispose);
      expect((await a.load(42))['a'], record('a', 1));
      final b = EpubHighlightsRepository(account: 'device-b', remote: remote);
      addTearDown(b.dispose);
      await b.save(42, record('b', 2));
      remote.offline = false;
      await b.flush();
      await a.flush();
      expect((await a.load(42)).keys, unorderedEquals(['a', 'b']));
      expect(await b.load(42), await a.load(42));
    },
  );
  test('removal survives stale replay and same-time edits converge', () async {
    final original = record('a', 1), removed = record('a', 3, deleted: true);
    final merged = mergeEpubHighlights(
      {'a': removed},
      {'a': original, 'b': record('b', 2)},
    );
    expect(merged['a'], removed);
    expect(mergeEpubHighlights({'a': original}, {'a': removed})['a'], removed);
    final left = {...original, 'revision': 'a'},
        right = {...original, 'revision': 'b'};
    expect(
      mergeEpubHighlights({'a': left}, {'a': right}),
      mergeEpubHighlights({'a': right}, {'a': left}),
    );
  });
  test('edit while upload is in flight stays pending', () async {
    final remote = Remote()..gate = Completer<void>();
    final repo = EpubHighlightsRepository(account: 'a', remote: remote);
    addTearDown(repo.dispose);
    await repo.save(42, record('a', 1));
    final upload = repo.flush();
    await Future<void>.delayed(Duration.zero);
    await repo.save(42, record('a', 2, deleted: true));
    remote.gate!.complete();
    await upload;
    expect((await repo.load(42, refreshRemote: false))['a']['deleted'], true);
    await repo.flush();
    expect(remote.records['a']['deleted'], true);
  });
  test(
    'storage remains partitioned by session and file hash is retained',
    () async {
      final remote = Remote()..offline = true;
      final a = EpubHighlightsRepository(
        account: 'server:user:domain-a',
        remote: remote,
      );
      final b = EpubHighlightsRepository(
        account: 'server:user:domain-b',
        remote: remote,
      );
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      await a.save(42, record('a', 1));
      expect(await b.load(42), isEmpty);
      expect((await a.load(42))['a']['sha256'], 'file-a');
    },
  );
  test('web session never persists data to preferences', () async {
    final repo = EpubHighlightsRepository(
      account: 'web',
      remote: Remote(),
      persistData: false,
    );
    addTearDown(repo.dispose);
    await repo.save(42, record('a', 1));
    await repo.flush();
    expect((await repo.load(42))['a'], record('a', 1));
    expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
  });
}
