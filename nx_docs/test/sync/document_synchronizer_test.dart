import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nx_docs/sync/native/background_uploader.dart';
import 'package:nx_docs/sync/clock.dart';
import 'package:nx_docs/sync/sync_models.dart';
import 'package:nx_offline/nx_offline.dart' as offline;
import 'package:nx_docs/sync/document_synchronizer.dart';
import 'package:nx_docs/sync/fake/memory_local_notes_store.dart';
import 'package:nx_docs/sync/fake/fake_document_remote_api.dart';

import '../support/offline_fixtures.dart';

void main() {
  late MemoryLocalNotesStore local;
  late FakeDocumentRemoteApi remote;
  late BackgroundUploader uploader;
  late DocumentSynchronizer synchronizer;

  setUp(() {
    local = MemoryLocalNotesStore(accountKey: 'user:1');
    remote = FakeDocumentRemoteApi(
      documents: [
        offlineTestDocument(id: 1, title: 'One'),
        offlineTestDocument(id: 2, title: 'Two'),
      ],
    );
    uploader = BackgroundUploader(
      account: const offline.AccountIdentity(
        serverId: 'nexus-primary',
        userId: '1',
        domainId: 1,
        application: 'nx_notes',
      ),
      localStore: local,
      remoteApi: remote,
      clock: const _Clock(),
      workerId: 'sync-test',
      uploadDelay: const Duration(hours: 1),
    );
    synchronizer = DocumentSynchronizer(
      localStore: local,
      remoteApi: remote,
      uploader: uploader,
    );
  });

  tearDown(() async {
    await synchronizer.close();
    await uploader.close();
    await local.dispose();
  });

  test('library sync downloads changes and removes server deletions', () async {
    await synchronizer.syncLibrary();
    expect((await local.getDocumentByRemoteId(1))?.document.title, 'One');
    expect((await local.getDocumentByRemoteId(2))?.document.title, 'Two');

    remote.replaceRemote(
      offlineTestDocument(
        id: 1,
        title: 'One changed',
        updatedAt: DateTime.utc(2026, 7, 30),
      ),
    );
    await remote.deleteDocument(2);

    await synchronizer.syncLibrary();

    expect(
      (await local.getDocumentByRemoteId(1))?.document.title,
      'One changed',
    );
    expect(await local.getDocumentByRemoteId(2), isNull);
  });

  test(
    'manifest-first sync keeps changed body requests to twenty items',
    () async {
      for (var id = 3; id <= 45; id++) {
        remote.replaceRemote(offlineTestDocument(id: id));
      }
      await synchronizer.syncLibrary();
      expect(remote.catalogFetchCount, 0);
      expect(remote.syncScopes.first, isNull);
      expect(remote.syncScopes.skip(1).map((scope) => scope!.length), [
        20,
        20,
        5,
      ]);
      expect((await local.documentManifest()).length, 45);
    },
  );

  test(
    'library sync downloads both documents and books for offline use',
    () async {
      remote.replaceRemote(
        offlineTestDocument(
          id: 3,
          title: 'Offline book',
        ).copyWith(modelTypeName: 'Book', readingState: 'to_read'),
      );

      await synchronizer.syncLibrary();

      final document = await local.getDocumentByRemoteId(1);
      final book = await local.getDocumentByRemoteId(3);
      expect(document?.document.modelTypeName, 'Document');
      expect(book?.document.modelTypeName, 'Book');
      expect(book?.document.hasFullDocument, isTrue);
    },
  );

  test(
    'concurrent library triggers share one complete reconciliation',
    () async {
      final barrier = Completer<void>();
      remote.syncBarrier = barrier.future;

      final first = synchronizer.syncLibrary();
      final second = synchronizer.syncLibrary();
      await Future<void>.delayed(Duration.zero);

      expect(remote.syncCount, 1);
      barrier.complete();
      await Future.wait(<Future<void>>[first, second]);
    },
  );

  test('concurrent document refreshes share one live batch', () async {
    await synchronizer.syncLibrary();
    remote.replaceRemote(
      offlineTestDocument(
        id: 1,
        title: 'Changed',
        updatedAt: DateTime.utc(2026, 7, 30),
      ),
    );
    final barrier = Completer<void>();
    remote.documentBarrier = barrier.future;
    final before = remote.liveBatchCount;

    final first = synchronizer.refreshDocument(1);
    final second = synchronizer.refreshDocument(1);
    await Future<void>.delayed(Duration.zero);

    expect(remote.liveBatchCount, before + 1);
    barrier.complete();
    await Future.wait(<Future<Object?>>[first, second]);
    expect((await local.getDocumentByRemoteId(1))?.document.title, 'Changed');
  });

  test(
    'different document demands are batched into one remote request',
    () async {
      for (var id = 3; id <= 15; id++) {
        remote.replaceRemote(
          offlineTestDocument(id: id, title: 'Document $id'),
        );
      }

      await Future.wait(<Future<void>>[
        for (var id = 1; id <= 15; id++)
          synchronizer.requestDocuments(<int>{id}),
      ]);

      expect(remote.liveBatchCount, 1);
      expect(remote.liveScopes.single, <int>{
        for (var id = 1; id <= 15; id++) id,
      });
    },
  );

  test('foreground finishes while the library manifest is waiting', () async {
    final barrier = Completer<void>();
    remote.beforeSync = (manifestOnly, _) async {
      if (manifestOnly) await barrier.future;
    };
    final library = synchronizer.syncLibrary();
    await Future<void>.delayed(Duration.zero);
    try {
      final document = await synchronizer
          .refreshDocument(1)
          .timeout(const Duration(seconds: 1));
      expect(document?.document.title, 'One');
      expect(remote.syncCount, 1);
      expect(remote.liveBatchCount, 1);
    } finally {
      barrier.complete();
      await library;
    }
  });
  test('library is not blocked by a foreground request', () async {
    final barrier = Completer<void>();
    var held = false;
    remote.beforeSync = (manifestOnly, ids) async {
      if (!manifestOnly && ids?.length == 1 && !held) {
        held = true;
        await barrier.future;
      }
    };
    final document = synchronizer.refreshDocument(1);
    await Future<void>.delayed(Duration.zero);
    try {
      await synchronizer.syncLibrary().timeout(const Duration(seconds: 1));
      expect((await local.getDocumentByRemoteId(2))?.document.title, 'Two');
    } finally {
      barrier.complete();
      await document;
    }
  });
  test(
    'unchanged library uses one request, one changed item adds one request',
    () async {
      await synchronizer.syncLibrary();
      var before = remote.syncCount;
      await synchronizer.syncLibrary();
      expect(remote.syncCount - before, 1);
      remote.replaceRemote(
        offlineTestDocument(
          id: 2,
          title: 'Changed',
          updatedAt: DateTime.utc(2026, 8),
        ),
      );
      before = remote.syncCount;
      await synchronizer.syncLibrary();
      expect(remote.syncCount - before, 2);
      expect(remote.syncScopes.last, {2});
    },
  );
  test(
    'blocked upload does not block downloads or overwrite the draft',
    () async {
      await synchronizer.syncLibrary();
      final existing = (await local.getDocumentByRemoteId(1))!;
      await local.saveDraftAndEnqueue(
        existing.copyWith(
          document: existing.document.copyWith(title: 'Local edit'),
          syncState: DocumentSyncState.locallyModified,
        ),
        operation: PendingOperation(
          operationId: 'edit',
          accountKey: 'user:1',
          documentKey: existing.key,
          type: PendingOperationType.update,
          payload: {},
          createdAt: DateTime.utc(2026, 8),
        ),
      );
      final barrier = Completer<void>();
      remote.saveBarrier = barrier.future;
      try {
        await synchronizer.syncLibrary().timeout(const Duration(seconds: 1));
        expect(
          (await local.getDocumentByRemoteId(1))?.document.title,
          'Local edit',
        );
        expect(uploader.state.activity, BackgroundUploadActivity.uploading);
      } finally {
        barrier.complete();
        await uploader.uploadPending();
      }
    },
  );
  test('reports checking, download, completion and failure', () async {
    final phases = <offline.DownloadPhase>[];
    final sub = synchronizer.progressChanges.listen((r) => phases.add(r.phase));
    await synchronizer.syncLibrary();
    expect(
      phases,
      containsAllInOrder([
        offline.DownloadPhase.checking,
        offline.DownloadPhase.downloading,
        offline.DownloadPhase.complete,
      ]),
    );
    expect(synchronizer.progress?.total, 2);
    expect(synchronizer.progress?.verified, 2);
    remote.error = StateError('No connection');
    await expectLater(synchronizer.syncLibrary(), throwsStateError);
    expect(synchronizer.progress?.phase, offline.DownloadPhase.incomplete);
    await sub.cancel();
  });
}

final class _Clock implements Clock {
  const _Clock();
  @override
  DateTime now() => DateTime.utc(2026, 7, 30, 12);
}
