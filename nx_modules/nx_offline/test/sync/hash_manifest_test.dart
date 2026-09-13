import 'package:flutter_test/flutter_test.dart';
import 'package:nx_offline/nx_offline.dart';

void main() {
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
