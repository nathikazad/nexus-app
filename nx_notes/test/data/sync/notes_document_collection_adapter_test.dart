import 'package:flutter_test/flutter_test.dart';
import 'package:nx_notes/application/ports/clock.dart';
import 'package:nx_notes/data/local/memory/memory_local_notes_store.dart';
import 'package:nx_notes/data/sync/notes_document_collection_adapter.dart';
import 'package:nx_notes/data/sync/notes_sync_store_adapter.dart';
import 'package:nx_notes/domain/links/linked_model.dart';
import 'package:nx_notes/domain/sync/sync_state.dart';
import 'package:nx_offline/nx_offline.dart' as offline;

import '../../support/offline_fixtures.dart';

void main() {
  test(
    'remote chapter links refresh while a local edit stays queued',
    () async {
      final store = MemoryLocalNotesStore(accountKey: 'prod:user-1');
      addTearDown(store.dispose);
      final local = offlineLocalDocument(body: 'local edit');
      await store.saveDraftAndEnqueue(
        local,
        operation: offlinePendingOperation(body: 'local edit'),
      );
      final remote = offlineTestDocument(body: 'server body').copyWith(
        links: <LinkedModel>[
          for (var chapter = 1; chapter <= 17; chapter++)
            LinkedModel(
              id: chapter,
              name: 'Chapter $chapter',
              modelType: 'Document',
            ),
        ],
      );
      const codec = NotesSyncDocumentCodec();
      final adapter = NotesDocumentCollectionAdapter(
        localStore: store,
        account: const offline.AccountScope(
          backend: 'prod',
          userId: 'user-1',
          application: 'nx_notes',
        ),
        clock: const _Clock(),
      );

      await adapter.applyRemote(
        offline.RemoteRecord(
          collection: notesDocumentCollection,
          modelType: 'Document',
          entityKey: const offline.EntityKey(localId: 'local-1', remoteId: 1),
          revision: const offline.Revision('rev-1'),
          payload: codec.encode(remote),
        ),
      );

      final refreshed = await store.getDocument(local.key);
      expect(refreshed!.document.document, 'local edit');
      expect(refreshed.document.links, hasLength(17));
      expect(refreshed.syncState, DocumentSyncState.queued);
      expect(await store.pendingOperations(), hasLength(1));
    },
  );
}

class _Clock implements Clock {
  const _Clock();

  @override
  DateTime now() => DateTime.utc(2026, 7, 27);
}
