import 'package:flutter_test/flutter_test.dart';
import 'package:nx_docs/application/ports/local_snapshot_store.dart';
import 'package:nx_docs/domain/document/document_identity.dart';
import 'package:nx_docs/domain/sync/local_snapshot.dart';

import '../offline_fixtures.dart';

typedef SnapshotStoreFactory = Future<LocalSnapshotStore> Function();

void runLocalSnapshotStoreContract({
  required SnapshotStoreFactory createStore,
}) {
  late LocalSnapshotStore store;

  setUp(() async => store = await createStore());

  test('stores immutable snapshots newest first', () async {
    for (var index = 1; index <= 2; index++) {
      await store.save(
        LocalSnapshot(
          snapshotId: 'snapshot-$index',
          accountKey: store.accountKey,
          documentKey: const DocumentKey(localId: 'local-1', remoteId: 1),
          document: offlineTestDocument(body: 'version $index'),
          createdAt: DateTime.utc(2026, 1, index),
          source: 'manual',
        ),
      );
    }

    final rows = await store.list(const DocumentKey(localId: 'local-1'));
    expect(rows.map((row) => row.document.document), <String>[
      'version 2',
      'version 1',
    ]);
  });

  test('rejects snapshots from another account', () async {
    await expectLater(
      store.save(
        LocalSnapshot(
          snapshotId: 'wrong',
          accountKey: 'other:user',
          documentKey: const DocumentKey(localId: 'local-1'),
          document: offlineTestDocument(),
          createdAt: DateTime.utc(2026),
          source: 'manual',
        ),
      ),
      throwsStateError,
    );
  });
}
