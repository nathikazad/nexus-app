import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nx_notes/application/native/background_uploader.dart';
import 'package:nx_notes/application/ports/clock.dart';
import 'package:nx_notes/application/sync/document_synchronizer.dart';
import 'package:nx_notes/data/local/memory/memory_local_notes_store.dart';
import 'package:nx_notes/data/remote/fake/fake_notes_remote_api.dart';

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
}

final class _Clock implements Clock {
  const _Clock();

  @override
  DateTime now() => DateTime.utc(2026, 7, 30, 12);
}
