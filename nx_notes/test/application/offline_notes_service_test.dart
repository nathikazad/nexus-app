import 'package:flutter_test/flutter_test.dart';
import 'package:nx_notes/application/offline_notes_service.dart';
import 'package:nx_notes/application/ports/clock.dart';
import 'package:nx_notes/application/ports/id_generator.dart';
import 'package:nx_notes/application/sync/document_sync_engine.dart';
import 'package:nx_notes/data/local/memory/memory_local_notes_store.dart';
import 'package:nx_notes/data/remote/fake/fake_remote_document_gateway.dart';
import 'package:nx_notes/domain/document/document_identity.dart';
import 'package:nx_notes/domain/document/document_query.dart';
import 'package:nx_notes/domain/sync/document_revision.dart';
import 'package:nx_notes/domain/sync/remote_document.dart';
import 'package:nx_notes/domain/sync/sync_state.dart';

import '../support/offline_fixtures.dart';

void main() {
  late MemoryLocalNotesStore store;
  late FakeRemoteDocumentGateway remote;
  late SequenceIds ids;
  late DocumentSyncEngine engine;
  late OfflineNotesService service;

  setUp(() {
    store = MemoryLocalNotesStore(accountKey: 'prod:user-1');
    remote = FakeRemoteDocumentGateway();
    ids = SequenceIds();
    engine = DocumentSyncEngine(
      localStore: store,
      remoteGateway: remote,
      clock: const FixedClock(),
      idGenerator: ids,
    );
    service = OfflineNotesService(
      localStore: store,
      syncEngine: engine,
      clock: const FixedClock(),
      idGenerator: ids,
    );
  });

  tearDown(() async {
    await engine.dispose();
    await store.dispose();
  });

  test('local records are observable before remote refresh', () async {
    await service.saveDraft(offlineLocalDocument(body: 'local first'));

    final rows = await service.watchDocuments(const DocumentQuery()).first;
    expect(rows.single.document.document, 'local first');
    expect(remote.updateCalls, 0);
  });

  test('save returns after document and outbox are committed', () async {
    final saved = await service.saveDraft(offlineLocalDocument(body: 'safe'));

    expect(saved.syncState, DocumentSyncState.queued);
    expect((await store.pendingOperations()).single.documentKey, saved.key);
  });

  test(
    'offline creation keeps local identity when sync assigns remote id',
    () async {
      final created = await service.createDraft(
        offlineTestDocument(id: 0, body: 'new offline'),
      );
      final localId = created.key.localId;

      await service.synchronize();
      final synchronized = await service.getDocument(
        DocumentKey(localId: localId),
      );

      expect(synchronized!.key.localId, localId);
      expect(synchronized.key.remoteId, isNotNull);
      expect(remote.documents, hasLength(1));
    },
  );

  test('remote draft is locally durable before synchronization', () async {
    final document = offlineTestDocument(id: 8, body: 'edited');
    remote.seed(
      RemoteDocument(
        key: const DocumentKey(localId: 'remote-8', remoteId: 8),
        document: offlineTestDocument(id: 8),
        revision: RemoteRevision(document.updatedAt.toUtc().toIso8601String()),
      ),
    );

    final saved = await service.saveRemoteDraft(document);

    expect(saved.document.document, 'edited');
    expect(remote.updateCalls, 0);
  });
}

class FixedClock implements Clock {
  const FixedClock();

  @override
  DateTime now() => DateTime.utc(2026, 1, 2);
}

class SequenceIds implements IdGenerator {
  var next = 0;

  @override
  String nextId() => 'id-${++next}';
}
