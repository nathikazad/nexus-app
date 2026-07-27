import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_notes/application/offline_notes_service.dart';
import 'package:nx_notes/application/ports/clock.dart';
import 'package:nx_notes/application/ports/id_generator.dart';
import 'package:nx_notes/composition/offline_providers.dart';
import 'package:nx_notes/data/local/memory/memory_local_notes_store.dart';
import 'package:nx_notes/data/remote/unavailable/unavailable_remote_document_gateway.dart';
import 'package:nx_notes/domain/document/document.dart';
import 'package:nx_notes/domain/document/document_identity.dart';
import 'package:nx_notes/domain/links/linked_model.dart';
import 'package:nx_notes/domain/sync/document_revision.dart';
import 'package:nx_notes/domain/sync/remote_document.dart';

import '../support/offline_fixtures.dart';
import '../support/offline_sync_engine.dart';

void main() {
  test('mobile catalog providers query downloaded documents only', () async {
    const accountKey = 'production:user-1';
    final store = MemoryLocalNotesStore(accountKey: accountKey);
    final engine = createOfflineTestSyncEngine(
      localStore: store,
      remoteGateway: const UnavailableRemoteDocumentGateway(),
      clock: const _Clock(),
      idGenerator: _Ids(),
    );
    addTearDown(engine.dispose);
    addTearDown(store.dispose);
    final service = OfflineNotesService(
      localStore: store,
      syncEngine: engine,
      clock: const _Clock(),
      idGenerator: _Ids(),
    );
    await store.importRemoteDocuments(<RemoteDocument>[
      RemoteDocument(
        key: const DocumentKey(localId: 'remote-1', remoteId: 1),
        document:
            offlineTestDocument(
              title: 'Offline Flutter notes',
              pinned: true,
            ).copyWith(
              tagsBySystem: const <String, List<String>>{
                'Topic': <String>['Flutter'],
              },
            ),
        revision: const RemoteRevision('rev-1'),
      ),
      RemoteDocument(
        key: const DocumentKey(localId: 'remote-2', remoteId: 2),
        document: offlineTestDocument(
          id: 2,
          title: 'A downloaded book',
          updatedAt: DateTime.utc(2026, 1, 2),
        ).copyWith(modelTypeName: 'Book'),
        revision: const RemoteRevision('rev-2'),
      ),
    ]);
    final container = ProviderContainer(
      overrides: [offlineNotesServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    final subscriptions = [
      container.listen(offlineRecentDocumentsProvider, (_, _) {}),
      container.listen(offlinePinnedDocumentsProvider, (_, _) {}),
      container.listen(offlineBooksProvider, (_, _) {}),
      container.listen(offlineDocumentSearchProvider('flutter'), (_, _) {}),
      container.listen(offlineTagSystemsProvider, (_, _) {}),
    ];
    addTearDown(() {
      for (final subscription in subscriptions) {
        subscription.close();
      }
    });

    final recent = await container.read(offlineRecentDocumentsProvider.future);
    final pinned = await container.read(offlinePinnedDocumentsProvider.future);
    final books = await container.read(offlineBooksProvider.future);
    final search = await container.read(
      offlineDocumentSearchProvider('flutter').future,
    );
    final tags = await container.read(offlineTagSystemsProvider.future);

    expect(recent.map((document) => document.id), <int>[2, 1]);
    expect(pinned.single.id, 1);
    expect(books.single.id, 2);
    expect(search.single.id, 1);
    final topic = tags.singleWhere((system) => system.name == 'Topic');
    expect(topic.nodes.single.name, 'Flutter');
  });

  test('an open document receives refreshed remote metadata', () async {
    const accountKey = 'production:user-1';
    final store = MemoryLocalNotesStore(accountKey: accountKey);
    final engine = createOfflineTestSyncEngine(
      localStore: store,
      remoteGateway: const UnavailableRemoteDocumentGateway(),
      clock: const _Clock(),
      idGenerator: _Ids(),
    );
    addTearDown(engine.dispose);
    addTearDown(store.dispose);
    final service = OfflineNotesService(
      localStore: store,
      syncEngine: engine,
      clock: const _Clock(),
      idGenerator: _Ids(),
    );
    const key = DocumentKey(localId: 'remote-1', remoteId: 1);
    await store.importRemoteDocuments(<RemoteDocument>[
      RemoteDocument(
        key: key,
        document: offlineTestDocument(
          id: 1,
          title: 'The Elephant in the Brain',
        ),
        revision: const RemoteRevision('rev-1'),
      ),
    ]);
    final container = ProviderContainer(
      overrides: [offlineNotesServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    final refreshed = Completer<NxDocument>();
    final subscription = container.listen(offlineDocumentProvider(1), (
      previous,
      next,
    ) {
      final document = next.value;
      if (document != null &&
          document.links.length == 17 &&
          !refreshed.isCompleted) {
        refreshed.complete(document);
      }
    }, fireImmediately: true);
    addTearDown(subscription.close);
    await container.read(offlineDocumentProvider(1).future);

    await store.mergeRemoteMetadata(
      RemoteDocument(
        key: key,
        document: offlineTestDocument(id: 1).copyWith(
          links: <LinkedModel>[
            for (var chapter = 1; chapter <= 17; chapter++)
              LinkedModel(
                id: chapter,
                name: 'Chapter $chapter',
                modelType: 'Document',
              ),
          ],
        ),
        revision: const RemoteRevision('rev-2'),
      ),
    );

    expect((await refreshed.future).links, hasLength(17));
  });
}

class _Clock implements Clock {
  const _Clock();

  @override
  DateTime now() => DateTime.utc(2026, 7, 21);
}

class _Ids implements IdGenerator {
  var value = 0;

  @override
  String nextId() => 'test-${value++}';
}
