import 'package:flutter_test/flutter_test.dart';
import 'package:nx_notes/application/ports/local_notes_store.dart';
import 'package:nx_notes/domain/catalog/catalog_query.dart';
import 'package:nx_notes/domain/document/document_identity.dart';
import 'package:nx_notes/domain/document/document_summary.dart';
import 'package:nx_notes/domain/sync/document_revision.dart';
import 'package:nx_notes/domain/sync/document_sync.dart';
import 'package:nx_notes/domain/sync/pending_operation.dart';
import 'package:nx_notes/domain/sync/remote_document.dart';
import 'package:nx_notes/domain/sync/sync_failure.dart';
import 'package:nx_notes/domain/sync/sync_state.dart';

import '../offline_fixtures.dart';

typedef LocalStoreFactory = Future<LocalNotesStore> Function();
typedef LocalStoreDisposer = Future<void> Function(LocalNotesStore store);

void runLocalNotesStoreContract({
  required LocalStoreFactory createStore,
  required LocalStoreDisposer disposeStore,
}) {
  late LocalNotesStore store;

  setUp(() async {
    store = await createStore();
  });

  tearDown(() async {
    await disposeStore(store);
  });

  test('saves a document and outbox entry together', () async {
    final document = offlineLocalDocument();
    final operation = offlinePendingOperation();

    await store.saveDraftAndEnqueue(document, operation: operation);

    final saved = await store.getDocument(document.key);
    expect(saved, isNotNull);
    expect(saved!.document.document, 'Test body');
    expect(saved.syncState, DocumentSyncState.queued);
    expect(await store.pendingOperations(), hasLength(1));
  });

  test('rejects an account mismatch without a partial write', () async {
    final document = offlineLocalDocument(accountKey: 'another:user');
    final operation = offlinePendingOperation(accountKey: 'another:user');

    await expectLater(
      store.saveDraftAndEnqueue(document, operation: operation),
      throwsStateError,
    );

    expect(await store.getDocument(document.key), isNull);
    expect(await store.pendingOperations(), isEmpty);
  });

  test('coalesces repeated saves for one document', () async {
    await store.saveDraftAndEnqueue(
      offlineLocalDocument(body: 'one'),
      operation: offlinePendingOperation(body: 'one'),
    );
    await store.saveDraftAndEnqueue(
      offlineLocalDocument(body: 'two'),
      operation: offlinePendingOperation(
        operationId: 'operation-2',
        body: 'two',
      ),
    );

    final operations = await store.pendingOperations();
    expect(operations, hasLength(1));
    expect(operations.single.operationId, 'operation-1');
    expect(operations.single.payload['body'], 'two');
    expect(
      (await store.getDocument(
        const DocumentKey(localId: 'local-1'),
      ))!.document.document,
      'two',
    );
  });

  test('claims one operation and respects its lease', () async {
    final now = DateTime.utc(2026, 1, 1, 12);
    await store.saveDraftAndEnqueue(
      offlineLocalDocument(),
      operation: offlinePendingOperation(),
    );

    final first = await store.claimNextOperation(
      workerId: 'worker-1',
      lease: const Duration(minutes: 1),
      now: now,
    );
    final blocked = await store.claimNextOperation(
      workerId: 'worker-2',
      lease: const Duration(minutes: 1),
      now: now,
    );
    final reclaimed = await store.claimNextOperation(
      workerId: 'worker-2',
      lease: const Duration(minutes: 1),
      now: now.add(const Duration(minutes: 1)),
    );

    expect(first!.leaseOwner, 'worker-1');
    expect(blocked, isNull);
    expect(reclaimed!.operationId, first.operationId);
    expect(reclaimed.leaseOwner, 'worker-2');
  });

  test('concurrent workers cannot claim the same operation', () async {
    final now = DateTime.utc(2026, 1, 1, 12);
    await store.saveDraftAndEnqueue(
      offlineLocalDocument(),
      operation: offlinePendingOperation(),
    );

    final claims = await Future.wait([
      store.claimNextOperation(
        workerId: 'tab-1',
        lease: const Duration(minutes: 1),
        now: now,
      ),
      store.claimNextOperation(
        workerId: 'tab-2',
        lease: const Duration(minutes: 1),
        now: now,
      ),
    ]);

    expect(claims.whereType<PendingOperation>(), hasLength(1));
  });

  test('failure persists retry metadata and releases lease', () async {
    final now = DateTime.utc(2026, 1, 1, 12);
    await store.saveDraftAndEnqueue(
      offlineLocalDocument(),
      operation: offlinePendingOperation(),
    );
    final claimed = await store.claimNextOperation(
      workerId: 'worker',
      lease: const Duration(minutes: 1),
      now: now,
    );

    await store.failOperation(
      claimed!.operationId,
      failure: const SyncFailure(
        kind: SyncFailureKind.transient,
        message: 'backend unavailable',
      ),
      retryAt: now.add(const Duration(minutes: 2)),
    );

    final failed = (await store.pendingOperations()).single;
    expect(failed.status, PendingOperationStatus.retryWaiting);
    expect(failed.attemptCount, 1);
    expect(failed.leaseOwner, isNull);
    expect(failed.lastError, 'backend unavailable');
    final local = await store.getDocument(claimed.documentKey);
    expect(local!.syncState, DocumentSyncState.retryWaiting);
  });

  test('completion assigns server identity and revision atomically', () async {
    final now = DateTime.utc(2026, 1, 1, 12);
    final document = offlineLocalDocument(
      remoteId: null,
      serverRevision: null,
      baseServerRevision: null,
    );
    await store.saveDraftAndEnqueue(
      document,
      operation: offlinePendingOperation(
        remoteId: null,
        type: PendingOperationType.create,
        baseRevision: null,
      ),
    );
    final claimed = await store.claimNextOperation(
      workerId: 'worker',
      lease: const Duration(minutes: 1),
      now: now,
    );

    await store.completeOperation(
      claimed!.operationId,
      result: const RemoteWriteResult(
        key: DocumentKey(localId: 'local-1', remoteId: 99),
        revision: RemoteRevision('rev-99'),
      ),
    );

    expect(await store.pendingOperations(), isEmpty);
    final saved = await store.getDocument(claimed.documentKey);
    expect(saved!.key.remoteId, 99);
    expect(saved.serverRevision, const RemoteRevision('rev-99'));
    expect(saved.baseServerRevision, const RemoteRevision('rev-99'));
    expect(saved.syncState, DocumentSyncState.synced);
  });

  test('remote import does not overwrite a locally dirty document', () async {
    await store.saveDraftAndEnqueue(
      offlineLocalDocument(body: 'local'),
      operation: offlinePendingOperation(body: 'local'),
    );
    await store.importRemoteDocuments(<RemoteDocument>[
      RemoteDocument(
        key: const DocumentKey(localId: 'local-1', remoteId: 1),
        document: offlineTestDocument(body: 'remote'),
        revision: const RemoteRevision('rev-2'),
      ),
    ]);

    final saved = await store.getDocument(
      const DocumentKey(localId: 'local-1'),
    );
    expect(saved!.document.document, 'local');
  });

  test(
    'manifest stores hashes and sync bundle rebuilds offline catalogs',
    () async {
      await store.applySyncBundle(
        DocumentSyncBundle(
          documents: <RemoteDocument>[
            RemoteDocument(
              key: const DocumentKey(localId: 'one', remoteId: 1),
              document: offlineTestDocument(id: 1, title: 'Synced document'),
              revision: const RemoteRevision('rev-1'),
              serverHash: 'hash-1',
            ),
            RemoteDocument(
              key: const DocumentKey(localId: 'book', remoteId: 2),
              document: offlineTestDocument(
                id: 2,
                title: 'Synced book',
              ).copyWith(modelTypeName: 'Book', pinned: true),
              revision: const RemoteRevision('rev-2'),
              serverHash: 'hash-2',
            ),
          ],
        ),
      );

      final manifest = await store.documentManifest();
      expect(
        manifest.map((entry) => (entry.documentId, entry.serverHash)).toList(),
        <(int, String?)>[(1, 'hash-1'), (2, 'hash-2')],
      );
      expect(
        (await store.readCatalog(
          const CatalogQuery.all(),
        )).map((row) => row.id),
        unorderedEquals(<int>[1, 2]),
      );
      expect(
        (await store.readCatalog(
          const CatalogQuery.books(),
        )).map((row) => row.id),
        <int>[2],
      );

      await store.applySyncBundle(
        const DocumentSyncBundle(deletedIds: <int>[1]),
      );
      expect(await store.getDocumentByRemoteId(1), isNull);
    },
  );

  test('sync bundle preserves a pending local edit', () async {
    await store.saveDraftAndEnqueue(
      offlineLocalDocument(body: 'pending local'),
      operation: offlinePendingOperation(body: 'pending local'),
    );

    await store.applySyncBundle(
      DocumentSyncBundle(
        documents: <RemoteDocument>[
          RemoteDocument(
            key: const DocumentKey(localId: 'local-1', remoteId: 1),
            document: offlineTestDocument(body: 'remote'),
            revision: const RemoteRevision('remote'),
            serverHash: 'remote-hash',
          ),
        ],
        deletedIds: const <int>[1],
      ),
    );

    expect(
      (await store.getDocument(
        const DocumentKey(localId: 'local-1'),
      ))!.document.document,
      'pending local',
    );
  });

  test('document streams publish initial and changed values', () async {
    final emissions = <String?>[];
    final subscription = store
        .watchDocument(const DocumentKey(localId: 'local-1'))
        .map((value) => value?.document.document)
        .listen(emissions.add);
    await Future<void>.delayed(Duration.zero);

    await store.saveDraftAndEnqueue(
      offlineLocalDocument(body: 'written'),
      operation: offlinePendingOperation(body: 'written'),
    );
    await Future<void>.delayed(Duration.zero);
    await subscription.cancel();

    expect(emissions, <String?>[null, 'written']);
  });

  test('local summary search filters cached documents', () async {
    await store.importRemoteDocuments(<RemoteDocument>[
      RemoteDocument(
        key: const DocumentKey(localId: 'one', remoteId: 1),
        document: offlineTestDocument(
          id: 1,
          title: 'Alpha roadmap',
          pinned: true,
        ),
        revision: const RemoteRevision('one'),
      ),
      RemoteDocument(
        key: const DocumentKey(localId: 'two', remoteId: 2),
        document: offlineTestDocument(id: 2, title: 'Beta notes'),
        revision: const RemoteRevision('two'),
      ),
    ]);

    final rows = await store
        .watchCatalog(const CatalogQuery.search('alpha'))
        .first;
    expect(rows.map((row) => row.id), <int>[1]);
  });

  test(
    'catalog membership preserves remote order and summary-only rows',
    () async {
      final first = offlineTestDocument(id: 10, title: 'First');
      final second = offlineTestDocument(id: 20, title: 'Second');

      await store.replaceCatalog(const CatalogQuery.recent(), <DocumentSummary>[
        DocumentSummary.fromDocument(second),
        DocumentSummary.fromDocument(first),
      ]);

      final rows = await store.watchCatalog(const CatalogQuery.recent()).first;
      expect(rows.map((row) => row.id), <int>[20, 10]);
      expect(await store.getDocumentByRemoteId(20), isNull);
    },
  );

  test('catalog refresh never replaces an already cached body', () async {
    final full = offlineTestDocument(id: 9, body: 'durable body');
    await store.importRemoteDocuments(<RemoteDocument>[
      RemoteDocument(
        key: const DocumentKey(localId: 'remote-9', remoteId: 9),
        document: full,
        revision: const RemoteRevision('full'),
      ),
    ]);

    await store.replaceCatalog(const CatalogQuery.books(), <DocumentSummary>[
      DocumentSummary.fromDocument(
        full.copyWith(title: 'Renamed from catalog'),
      ),
    ]);

    final cached = await store.getDocumentByRemoteId(9);
    final catalog = await store.watchCatalog(const CatalogQuery.books()).first;
    expect(catalog.single.title, 'Renamed from catalog');
    expect(cached!.document.title, full.title);
    expect(cached.document.document, 'durable body');
    expect(cached.document.hasFullDocument, isTrue);
  });

  test(
    'local pin changes update the cached pinned catalog immediately',
    () async {
      final remote = offlineTestDocument(id: 7, pinned: false);
      const key = DocumentKey(localId: 'remote-7', remoteId: 7);
      await store.importRemoteDocuments(<RemoteDocument>[
        RemoteDocument(
          key: key,
          document: remote,
          revision: const RemoteRevision('initial'),
        ),
      ]);

      final local = (await store.getDocument(key))!;
      await store.saveDraftAndEnqueue(
        local.copyWith(document: remote.copyWith(pinned: true)),
        operation: PendingOperation(
          operationId: 'pin',
          accountKey: store.accountKey,
          documentKey: key,
          type: PendingOperationType.update,
          payload: const <String, Object?>{},
          createdAt: DateTime.utc(2026, 1, 2),
        ),
      );
      expect(
        (await store.readCatalog(const CatalogQuery.pinned())).single.id,
        7,
      );

      await store.saveDraftAndEnqueue(
        local.copyWith(document: remote.copyWith(pinned: false)),
        operation: PendingOperation(
          operationId: 'unpin',
          accountKey: store.accountKey,
          documentKey: key,
          type: PendingOperationType.update,
          payload: const <String, Object?>{},
          createdAt: DateTime.utc(2026, 1, 3),
        ),
      );
      expect(await store.readCatalog(const CatalogQuery.pinned()), isEmpty);
    },
  );
}
