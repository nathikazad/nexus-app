import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_notes/application/ports/clock.dart';
import 'package:nx_notes/application/ports/id_generator.dart';
import 'package:nx_notes/application/ports/remote_document_gateway.dart';
import 'package:nx_notes/application/sync/document_sync_engine.dart';
import 'package:nx_notes/data/local/drift/drift_local_notes_store.dart';
import 'package:nx_notes/data/local/drift/notes_database.dart';
import 'package:nx_notes/data/remote/fake/fake_remote_document_gateway.dart';
import 'package:nx_notes/domain/document/document_identity.dart';
import 'package:nx_notes/domain/document/document_query.dart';
import 'package:nx_notes/domain/sync/document_revision.dart';
import 'package:nx_notes/domain/sync/pending_operation.dart';
import 'package:nx_notes/domain/sync/remote_document.dart';
import 'package:nx_notes/domain/sync/sync_failure.dart';

import '../support/offline_fixtures.dart';

void main() {
  const accountKey = 'prod:user-1';

  test('the complete downloaded library survives a process restart', () async {
    final fixture = await DriftFixture.create(accountKey);
    addTearDown(fixture.dispose);
    final remote = FakeRemoteDocumentGateway();
    for (var id = 1; id <= 4; id++) {
      remote.seed(
        RemoteDocument(
          key: DocumentKey(localId: 'remote-$id', remoteId: id),
          document: offlineTestDocument(
            id: id,
            title: 'Persistent document $id',
            body: 'Downloaded body $id',
            updatedAt: DateTime.utc(2026, 1, id),
          ),
          revision: RemoteRevision('rev-$id'),
        ),
      );
    }
    final engine = fixture.engine(remote);
    final firstSync = await engine.synchronize(reason: SyncReason.appStarted);
    await engine.dispose();

    expect(firstSync.pulledCount, 4);
    await fixture.reopen();

    final downloaded = await fixture.store
        .watchDocuments(const DocumentQuery())
        .first;
    expect(downloaded.map((row) => row.document.id), <int>[4, 3, 2, 1]);
    for (var id = 1; id <= 4; id++) {
      final cached = await fixture.store.getDocument(
        DocumentKey(localId: 'remote-$id', remoteId: id),
      );
      expect(cached?.document.document, 'Downloaded body $id');
    }
  });

  test('offline edit survives process restart and then synchronizes', () async {
    final fixture = await DriftFixture.create(accountKey);
    addTearDown(fixture.dispose);
    final remote = FakeRemoteDocumentGateway()
      ..seed(
        RemoteDocument(
          key: const DocumentKey(localId: 'local-1', remoteId: 1),
          document: offlineTestDocument(),
          revision: const RemoteRevision('rev-1'),
        ),
      );
    await fixture.store.saveDraftAndEnqueue(
      offlineLocalDocument(body: 'durable edit'),
      operation: offlinePendingOperation(body: 'durable edit'),
    );

    await fixture.reopen();
    final engine = fixture.engine(remote);
    addTearDown(engine.dispose);
    final result = await engine.synchronize();

    expect(result.pushedCount, 1);
    expect(remote.documents.single.document.document, 'durable edit');
    expect(await fixture.store.pendingOperations(), isEmpty);
  });

  test('expired claimed operation is recovered after restart', () async {
    final fixture = await DriftFixture.create(accountKey);
    addTearDown(fixture.dispose);
    final remote = FakeRemoteDocumentGateway()
      ..seed(
        RemoteDocument(
          key: const DocumentKey(localId: 'local-1', remoteId: 1),
          document: offlineTestDocument(),
          revision: const RemoteRevision('rev-1'),
        ),
      );
    await fixture.store.saveDraftAndEnqueue(
      offlineLocalDocument(body: 'claimed edit'),
      operation: offlinePendingOperation(body: 'claimed edit'),
    );
    await fixture.store.claimNextOperation(
      workerId: 'crashed-worker',
      lease: const Duration(minutes: 1),
      now: fixture.clock.value,
    );

    await fixture.reopen();
    fixture.clock.value = fixture.clock.value.add(const Duration(minutes: 1));
    final engine = fixture.engine(remote);
    addTearDown(engine.dispose);
    final result = await engine.synchronize();

    expect(result.pushedCount, 1);
    expect(remote.documents.single.document.document, 'claimed edit');
  });

  test(
    'server-applied write is safely replayed after database restart',
    () async {
      final fixture = await DriftFixture.create(accountKey);
      addTearDown(fixture.dispose);
      final remote = FakeRemoteDocumentGateway();
      await fixture.store.saveDraftAndEnqueue(
        offlineLocalDocument(
          remoteId: null,
          serverRevision: null,
          baseServerRevision: null,
        ),
        operation: offlinePendingOperation(
          remoteId: null,
          type: PendingOperationType.create,
          baseRevision: null,
        ),
      );
      remote.failAfterNextCommit(
        const RemoteGatewayException(
          SyncFailure(
            kind: SyncFailureKind.transient,
            message: 'lost response',
          ),
        ),
      );
      var engine = fixture.engine(remote);
      await engine.synchronize();
      await engine.dispose();

      final retryAt =
          (await fixture.store.pendingOperations()).single.nextAttemptAt!;
      await fixture.reopen();
      fixture.clock.value = retryAt;
      engine = fixture.engine(remote);
      addTearDown(engine.dispose);
      await engine.synchronize();

      expect(remote.documents, hasLength(1));
      expect(remote.createCalls, 2);
      expect(await fixture.store.pendingOperations(), isEmpty);
    },
  );

  test('conflict snapshots survive a database restart', () async {
    final fixture = await DriftFixture.create(accountKey);
    addTearDown(fixture.dispose);
    final remote = FakeRemoteDocumentGateway()
      ..seed(
        RemoteDocument(
          key: const DocumentKey(localId: 'local-1', remoteId: 1),
          document: offlineTestDocument(body: 'server edit'),
          revision: const RemoteRevision('rev-2'),
        ),
      );
    await fixture.store.saveDraftAndEnqueue(
      offlineLocalDocument(body: 'local edit'),
      operation: offlinePendingOperation(body: 'local edit'),
    );
    final engine = fixture.engine(remote);
    await engine.synchronize();
    await engine.dispose();

    await fixture.reopen();
    final conflicts = await fixture.store.conflicts();

    expect(conflicts, hasLength(1));
    expect(conflicts.single.localDocument.document, 'local edit');
    expect(conflicts.single.remoteDocument.document, 'server edit');
  });

  test('processes a bounded queue entirely from durable storage', () async {
    final fixture = await DriftFixture.create(accountKey);
    addTearDown(fixture.dispose);
    final remote = FakeRemoteDocumentGateway();
    for (var index = 0; index < 100; index++) {
      final localId = 'queued-$index';
      await fixture.store.saveDraftAndEnqueue(
        offlineLocalDocument(
          localId: localId,
          remoteId: null,
          body: 'body $index',
          serverRevision: null,
          baseServerRevision: null,
        ),
        operation: offlinePendingOperation(
          operationId: 'operation-$index',
          localId: localId,
          remoteId: null,
          type: PendingOperationType.create,
          baseRevision: null,
          createdAt: fixture.clock.value.add(Duration(seconds: index)),
        ),
      );
    }

    final engine = fixture.engine(remote);
    addTearDown(engine.dispose);
    final result = await engine.synchronize();

    expect(result.pushedCount, 100);
    expect(remote.documents, hasLength(100));
    expect(await fixture.store.pendingOperations(), isEmpty);
  });
}

class DriftFixture {
  DriftFixture._({
    required this.directory,
    required this.file,
    required this.accountKey,
    required this.database,
    required this.store,
    required this.clock,
  });

  final Directory directory;
  final File file;
  final String accountKey;
  NotesDatabase database;
  DriftLocalNotesStore store;
  final MutableClock clock;

  static Future<DriftFixture> create(String accountKey) async {
    final directory = await Directory.systemTemp.createTemp(
      'nx_notes_sync_integration_',
    );
    final file = File('${directory.path}/notes.sqlite');
    final database = NotesDatabase(NativeDatabase(file));
    return DriftFixture._(
      directory: directory,
      file: file,
      accountKey: accountKey,
      database: database,
      store: DriftLocalNotesStore(database: database, accountKey: accountKey),
      clock: MutableClock(DateTime.utc(2026, 1, 2)),
    );
  }

  Future<void> reopen() async {
    await database.close();
    database = NotesDatabase(NativeDatabase(file));
    store = DriftLocalNotesStore(database: database, accountKey: accountKey);
  }

  DocumentSyncEngine engine(RemoteDocumentGateway remote) {
    return DocumentSyncEngine(
      localStore: store,
      remoteGateway: remote,
      clock: clock,
      idGenerator: SequenceIdGenerator(),
    );
  }

  Future<void> dispose() async {
    await database.close();
    if (directory.existsSync()) await directory.delete(recursive: true);
  }
}

class MutableClock implements Clock {
  MutableClock(this.value);

  DateTime value;

  @override
  DateTime now() => value;
}

class SequenceIdGenerator implements IdGenerator {
  var _next = 0;

  @override
  String nextId() => '${++_next}';
}
