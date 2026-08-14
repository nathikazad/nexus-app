import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nx_docs/documents/document_session.dart';
import 'package:nx_docs/sync/native/background_uploader.dart';
import 'package:nx_docs/sync/native/native_document_workspace.dart';
import 'package:nx_docs/sync/clock.dart';
import 'package:nx_docs/sync/id_generator.dart';
import 'package:nx_docs/sync/document_synchronizer.dart';
import 'package:nx_docs/sync/fake/memory_local_notes_store.dart';
import 'package:nx_docs/sync/fake/fake_document_remote_api.dart';
import 'package:nx_docs/library/models/catalog_query.dart';
import 'package:nx_docs/documents/document_models.dart';
import 'package:nx_docs/sync/sync_models.dart';

import '../../support/offline_fixtures.dart';

void main() {
  late MemoryLocalNotesStore local;
  late FakeDocumentRemoteApi remote;
  late _Clock clock;
  late _Ids ids;
  late BackgroundUploader uploader;
  late NativeDocumentWorkspace workspace;

  setUp(() {
    local = MemoryLocalNotesStore(accountKey: 'user:1');
    remote = FakeDocumentRemoteApi();
    clock = _Clock(DateTime.utc(2026, 7, 27, 12));
    ids = _Ids();
    uploader = BackgroundUploader(
      localStore: local,
      remoteApi: remote,
      clock: clock,
      workerId: 'test-worker',
      uploadDelay: const Duration(hours: 1),
    );
    workspace = NativeDocumentWorkspace(
      localStore: local,
      remoteApi: remote,
      uploader: uploader,
      synchronizer: DocumentSynchronizer(
        localStore: local,
        remoteApi: remote,
        uploader: uploader,
      ),
      clock: clock,
      idGenerator: ids,
    );
  });

  tearDown(() async {
    await workspace.close();
    await uploader.close();
    await local.dispose();
  });

  test('cached catalog is emitted without a network request', () async {
    final cached = offlineTestDocument(id: 7, title: 'Cached recent');
    await local.replaceCatalog(const CatalogQuery.recent(), <DocumentSummary>[
      DocumentSummary.fromDocument(cached),
    ]);
    final network = Completer<void>();
    remote
      ..catalogBarrier = network.future
      ..replaceRemote(offlineTestDocument(id: 8, title: 'Remote recent'));

    final state = await workspace
        .watchCatalog(const CatalogQuery.recent())
        .firstWhere((state) => state.items.isNotEmpty);

    expect(state.items.single.title, 'Cached recent');
    expect(state.isRefreshing, isFalse);
    expect(remote.catalogFetchCount, 0);
    expect(network.isCompleted, isFalse);
    network.complete();
  });

  test(
    'library sync refreshes catalogs when document hashes are unchanged',
    () async {
      final initialBook = offlineTestDocument(
        id: 9,
        title: 'Correct book',
      ).copyWith(modelTypeName: 'Book', readingState: 'to_read');
      remote.replaceRemote(initialBook);
      final initial = await remote.syncDocuments(manifest: const []);
      await local.importRemoteDocuments(initial.documents);
      await local.replaceCatalog(const CatalogQuery.books(), <DocumentSummary>[
        DocumentSummary.fromDocument(initialBook),
      ]);
      final book = initialBook.copyWith(
        readingState: 'read',
        updatedAt: initialBook.updatedAt.add(const Duration(minutes: 1)),
      );
      remote.replaceRemote(book);

      expect(
        (await local.readCatalog(
          const CatalogQuery.books(),
        )).single.readingState,
        'to_read',
      );

      await workspace.syncLibrary();

      expect(remote.syncCount, 2);
      expect(remote.catalogFetchCount, 0);
      expect(
        (await local.readCatalog(
          const CatalogQuery.books(),
        )).single.readingState,
        'read',
      );
    },
  );

  test(
    'opening is local-only and foreground demand fetches remote once',
    () async {
      final cached = offlineTestDocument(id: 7, title: 'Cached body');
      await _import(local, cached);
      final network = Completer<void>();
      remote
        ..syncBarrier = network.future
        ..replaceRemote(cached.copyWith(title: 'Remote body'));

      final first = workspace.openDocument(7);
      final second = workspace.openDocument(7);
      final ready = await first.states.firstWhere(
        (state) => state.phase == DocumentPhase.ready,
      );

      expect(identical(first, second), isTrue);
      expect(ready.document!.title, 'Cached body');
      expect(remote.syncCount, 0);

      final demand = workspace.ensureDocumentAvailable(7);
      await Future<void>.delayed(Duration.zero);
      expect(remote.syncCount, 1);
      network.complete();
      await demand;
    },
  );

  test(
    'uncached document reports unavailable when remote is offline',
    () async {
      remote.error = StateError('offline');

      final session = workspace.openDocument(99);
      final demand = workspace.ensureDocumentAvailable(99);
      final state = await session.states.firstWhere(
        (state) => state.phase == DocumentPhase.unavailableOffline,
      );
      await demand;

      expect(state.document, isNull);
      expect(state.error, isA<StateError>());
    },
  );

  test('save is durable locally before background upload', () async {
    final initial = offlineTestDocument(id: 3);
    await _import(local, initial);
    remote.replaceRemote(initial);
    final session = workspace.openDocument(3);
    await session.states.firstWhere((state) => !state.isRefreshing);
    final blockedUpload = Completer<void>();
    remote.saveBarrier = blockedUpload.future;

    await session.saveDraft(initial.copyWith(document: 'local draft'));

    final saved = await local.getDocumentByRemoteId(3);
    expect(saved!.document.document, 'local draft');
    expect(saved.syncState, DocumentSyncState.queued);
    expect(await local.pendingOperations(), hasLength(1));
    expect(remote.saveCount, 0);
    blockedUpload.complete();
  });

  test('applied upload clears the outbox', () async {
    final initial = offlineTestDocument(id: 4);
    remote.replaceRemote(initial);
    await _queue(
      local,
      initial.copyWith(
        document: 'newer',
        updatedAt: DateTime.utc(2026, 7, 27, 13),
      ),
    );

    await uploader.uploadPending();

    expect(await local.pendingOperations(), isEmpty);
    expect(
      (await local.getDocumentByRemoteId(4))!.syncState,
      DocumentSyncState.synced,
    );
    expect(remote.documents.single.document, 'newer');
  });

  test(
    'stale upload is discarded and replaced by the remote document',
    () async {
      final remoteDocument = offlineTestDocument(
        id: 5,
        body: 'iphone version',
        updatedAt: DateTime.utc(2026, 7, 27, 15),
      );
      remote.replaceRemote(remoteDocument);
      await _queue(
        local,
        offlineTestDocument(
          id: 5,
          body: 'old laptop version',
          updatedAt: DateTime.utc(2026, 7, 27, 14),
        ),
      );

      await uploader.uploadPending();

      expect(await local.pendingOperations(), isEmpty);
      final saved = await local.getDocumentByRemoteId(5);
      expect(saved!.document.document, 'iphone version');
      expect(saved.syncState, DocumentSyncState.synced);
    },
  );

  test('network failure retains the exact draft and retry timestamp', () async {
    final editTime = DateTime.utc(2026, 7, 27, 16);
    final draft = offlineTestDocument(
      id: 6,
      body: 'not uploaded yet',
      updatedAt: editTime,
    );
    await _queue(local, draft);
    remote.error = StateError('offline');

    await uploader.uploadPending();

    final pending = (await local.pendingOperations()).single;
    final saved = await local.getDocumentByRemoteId(6);
    expect(pending.status, PendingOperationStatus.retryWaiting);
    expect(saved!.document.updatedAt, editTime);
    expect(saved.document.document, 'not uploaded yet');
  });
}

Future<void> _import(MemoryLocalNotesStore local, dynamic document) {
  return local.importRemoteDocuments(<RemoteDocument>[
    RemoteDocument(
      key: DocumentKey(
        localId: 'remote-${document.id}',
        remoteId: document.id as int,
      ),
      document: document,
      revision: RemoteRevision(
        (document.updatedAt as DateTime).toUtc().toIso8601String(),
      ),
    ),
  ]);
}

Future<void> _queue(MemoryLocalNotesStore local, dynamic document) {
  final key = DocumentKey(
    localId: 'remote-${document.id}',
    remoteId: document.id as int,
  );
  final timestamp = document.updatedAt as DateTime;
  return local.saveDraftAndEnqueue(
    LocalDocument(
      key: key,
      accountKey: local.accountKey,
      document: document,
      localUpdatedAt: timestamp,
      serverRevision: const RemoteRevision('previous'),
      baseServerRevision: const RemoteRevision('previous'),
      syncState: DocumentSyncState.locallyModified,
    ),
    operation: PendingOperation(
      operationId: 'operation-${document.id}',
      accountKey: local.accountKey,
      documentKey: key,
      type: PendingOperationType.update,
      payload: <String, Object?>{
        'updated_at': timestamp.toUtc().toIso8601String(),
      },
      createdAt: timestamp,
    ),
  );
}

final class _Clock implements Clock {
  _Clock(this.value);

  DateTime value;

  @override
  DateTime now() => value;
}

final class _Ids implements IdGenerator {
  int _next = 0;

  @override
  String nextId() => 'id-${_next++}';
}
