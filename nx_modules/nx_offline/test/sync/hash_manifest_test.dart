import 'package:flutter_test/flutter_test.dart';
import 'package:nx_offline/nx_offline.dart';

void main() {
  test('a body from a newer snapshot is rejected before applying', () async {
    var applied = false;
    await expectLater(
      reconcileHashManifest<int, (int, String), (int, String)>(
        manifest: [(1, 'old')],
        keyOf: (e) => e.$1,
        valueKeyOf: (e) => e.$1,
        verified: (_) async => false,
        download: (_) async => const HashDownload([(1, 'new')]),
        matchesEntry: (entry, value) => entry.$2 == value.$2,
        applyBatch: (_) async {
          applied = true;
          return [];
        },
      ),
      throwsStateError,
    );
    expect(applied, false);
  });
  test(
    'bounded downloads request only missing items and commit before next page',
    () async {
      final calls = <Set<int>>[];
      final saved = <int>[];
      await reconcileHashManifest<int, int, int>(
        manifest: List.generate(9, (i) => i),
        downloadPageSize: 3,
        keyOf: (x) => x,
        valueKeyOf: (x) => x,
        verified: (x) async => x == 0,
        download: (ids) async {
          expect(saved.length, calls.length * 3);
          calls.add(ids);
          return HashDownload(ids.toList());
        },
        applyBatch: (items) async {
          saved.addAll(items);
          return [];
        },
      );
      expect(calls, [
        {1, 2, 3},
        {4, 5, 6},
        {7, 8},
      ]);
      expect(saved.length, 8);
    },
  );
  test('unchanged manifest never downloads or writes', () async {
    final result = await reconcileHashManifest<int, int, int>(
      manifest: [1, 2],
      keyOf: (x) => x,
      valueKeyOf: (x) => x,
      verified: (_) async => true,
      download: (_) => throw StateError('unexpected download'),
      applyBatch: (_) => throw StateError('unexpected write'),
    );
    expect(result, [1, 2]);
  });
  test('downloads only missing bodies, accepts explicit deletion', () async {
    final writes = <int>[];
    final result = await reconcileHashManifest<int, int, int>(
      manifest: [1, 2, 3],
      keyOf: (x) => x,
      valueKeyOf: (x) => x,
      verified: (x) async => x == 1,
      download: (ids) async {
        expect(ids, {2, 3});
        return const HashDownload([2], deleted: {3});
      },
      applyBatch: (page) async {
        writes.addAll(page);
        return [];
      },
    );
    expect(result, [1, 2]);
    expect(writes, [2]);
  });
  for (final values in [
    <int>[],
    [1, 1],
    [99],
  ]) {
    test(
      'rejects incomplete, duplicate or unexpected response $values',
      () async {
        await expectLater(
          reconcileHashManifest<int, int, int>(
            manifest: [1],
            keyOf: (x) => x,
            valueKeyOf: (x) => x,
            verified: (_) async => false,
            download: (_) async => HashDownload(values),
            applyBatch: (_) async => [],
          ),
          throwsStateError,
        );
      },
    );
  }
}
