import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nx_docs/application/native/background_uploader.dart';
import 'package:nx_docs/application/ports/clock.dart';
import 'package:nx_docs/application/sync/document_synchronizer.dart';
import 'package:nx_docs/data/local/memory/memory_local_notes_store.dart';
import 'package:nx_docs/data/remote/fake/fake_notes_remote_api.dart';

import '../../support/offline_fixtures.dart';

void main() {
  late MemoryLocalNotesStore local;
  late FakeNotesRemoteApi remote;
  late BackgroundUploader uploader;
  late DocumentSynchronizer synchronizer;

  setUp(() {
    local = MemoryLocalNotesStore(accountKey: 'user:1');
    remote = FakeNotesRemoteApi(
      documents: [
        offlineTestDocument(id: 1, title: 'One'),
        offlineTestDocument(id: 2, title: 'Two'),
      ],
    );
    uploader = BackgroundUploader(
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

  test('concurrent document refreshes share one remote hash check', () async {
    await synchronizer.syncLibrary();
    remote.replaceRemote(
      offlineTestDocument(
        id: 1,
        title: 'Changed',
        updatedAt: DateTime.utc(2026, 7, 30),
      ),
    );
    final barrier = Completer<void>();
    remote.syncBarrier = barrier.future;
    final before = remote.syncCount;

    final first = synchronizer.refreshDocument(1);
    final second = synchronizer.refreshDocument(1);
    await Future<void>.delayed(Duration.zero);

    expect(remote.syncCount, before + 1);
    barrier.complete();
    await Future.wait(<Future<Object?>>[first, second]);
    expect((await local.getDocumentByRemoteId(1))?.document.title, 'Changed');
  });

  test(
    'document opened during library sync reuses the library result',
    () async {
      final barrier = Completer<void>();
      remote.syncBarrier = barrier.future;

      final library = synchronizer.syncLibrary();
      await Future<void>.delayed(Duration.zero);
      expect(remote.syncCount, 1);

      final document = synchronizer.refreshDocument(1);
      await Future<void>.delayed(Duration.zero);
      expect(remote.syncCount, 1);

      barrier.complete();
      await library;
      expect((await document)?.document.title, 'One');
      expect(remote.syncCount, 1);
    },
  );

  test('library sync waits for an active targeted document refresh', () async {
    final barrier = Completer<void>();
    remote.syncBarrier = barrier.future;

    final document = synchronizer.refreshDocument(1);
    await Future<void>.delayed(Duration.zero);
    expect(remote.syncCount, 1);

    final library = synchronizer.syncLibrary();
    await Future<void>.delayed(Duration.zero);
    expect(remote.syncCount, 1);

    barrier.complete();
    expect((await document)?.document.title, 'One');
    await library;
    expect(remote.syncCount, 2);
  });
}

final class _Clock implements Clock {
  const _Clock();

  @override
  DateTime now() => DateTime.utc(2026, 7, 30, 12);
}
