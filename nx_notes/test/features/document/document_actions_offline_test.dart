import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_notes/application/offline_notes_service.dart';
import 'package:nx_notes/application/ports/clock.dart';
import 'package:nx_notes/application/ports/id_generator.dart';
import 'package:nx_notes/composition/offline_providers.dart';
import 'package:nx_notes/data/local/memory/memory_local_notes_store.dart';
import 'package:nx_notes/data/remote/fake/fake_remote_document_gateway.dart';
import 'package:nx_notes/domain/document/document_identity.dart';
import 'package:nx_notes/features/document/document_actions.dart';

import '../../support/offline_fixtures.dart';
import '../../support/offline_sync_engine.dart';

void main() {
  test(
    'editor-facing save commits title and body locally before returning',
    () async {
      final store = MemoryLocalNotesStore(accountKey: 'prod:user-1');
      final remote = FakeRemoteDocumentGateway();
      final ids = SequenceIds();
      final engine = createOfflineTestSyncEngine(
        localStore: store,
        remoteGateway: remote,
        clock: const FixedClock(),
        idGenerator: ids,
      );
      final service = OfflineNotesService(
        localStore: store,
        syncEngine: engine,
        clock: const FixedClock(),
        idGenerator: ids,
      );
      final container = ProviderContainer(
        overrides: [offlineNotesServiceProvider.overrideWithValue(service)],
      );
      addTearDown(() async {
        container.dispose();
        await engine.dispose();
        await store.dispose();
      });
      final edited = offlineTestDocument(
        id: 9,
        title: 'Offline title',
        body: 'Offline body',
      );

      await container
          .read(documentMutationControllerProvider)
          .saveDraft(edited);

      final local = await store.getDocument(
        const DocumentKey(localId: 'remote-9', remoteId: 9),
      );
      expect(local!.document.title, 'Offline title');
      expect(local.document.document, 'Offline body');
      expect(await store.pendingOperations(), hasLength(1));
      expect(remote.updateCalls, 0);
    },
  );

  test('disposing feature providers retains durable pending work', () async {
    final store = MemoryLocalNotesStore(accountKey: 'prod:user-1');
    final engine = createOfflineTestSyncEngine(
      localStore: store,
      remoteGateway: FakeRemoteDocumentGateway(),
      clock: const FixedClock(),
      idGenerator: SequenceIds(),
    );
    final service = OfflineNotesService(
      localStore: store,
      syncEngine: engine,
      clock: const FixedClock(),
      idGenerator: SequenceIds(),
    );
    final container = ProviderContainer(
      overrides: [offlineNotesServiceProvider.overrideWithValue(service)],
    );
    await container
        .read(documentMutationControllerProvider)
        .saveDraft(offlineTestDocument(id: 10));

    container.dispose();

    expect(await store.pendingOperations(), hasLength(1));
    await engine.dispose();
    await store.dispose();
  });
}

class FixedClock implements Clock {
  const FixedClock();

  @override
  DateTime now() => DateTime.utc(2026, 1, 2);
}

class SequenceIds implements IdGenerator {
  var value = 0;

  @override
  String nextId() => 'id-${++value}';
}
