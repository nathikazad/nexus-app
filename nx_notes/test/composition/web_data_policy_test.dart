import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_notes/composition/offline_providers.dart';
import 'package:nx_notes/data/document/fake_document_repository.dart';
import 'package:nx_notes/data/providers.dart';
import 'package:nx_notes/domain/document/document.dart';
import 'package:nx_notes/features/document/document_actions.dart';

void main() {
  test(
    'web policy reads the catalog directly and creates no replica',
    () async {
      final repository = FakeDocumentRepository();
      final container = ProviderContainer(
        overrides: [
          offlineEnabledProvider.overrideWithValue(false),
          documentRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(localNotesStoreProvider), isNull);
      expect(container.read(documentSyncEngineProvider), isNull);
      expect(container.read(offlineNotesServiceProvider), isNull);

      final expectedAll = await repository.listAll();
      final expectedRecent = await repository.listRecent(limit: 20);
      final expectedPinned = await repository.listPinned(limit: 20);
      final expectedBooks = await repository.listBooks(limit: 100);
      final expectedTags = await repository.listTagSystems();
      final documentId = expectedAll.first.id;
      final subscriptions = [
        container.listen(offlineAllDocumentsProvider, (_, _) {}),
        container.listen(offlineRecentDocumentsProvider, (_, _) {}),
        container.listen(offlinePinnedDocumentsProvider, (_, _) {}),
        container.listen(offlineBooksProvider, (_, _) {}),
        container.listen(offlineTagSystemsProvider, (_, _) {}),
        container.listen(offlineDocumentProvider(documentId), (_, _) {}),
      ];
      addTearDown(() {
        for (final subscription in subscriptions) {
          subscription.close();
        }
      });

      expect(
        (await _emitted(
          container.read(offlineAllDocumentsProvider.future),
          'all documents',
        )).map((document) => document.id),
        expectedAll.map((document) => document.id),
      );
      expect(
        (await _emitted(
          container.read(offlineRecentDocumentsProvider.future),
          'recent documents',
        )).map((document) => document.id),
        expectedRecent.map((document) => document.id),
      );
      expect(
        (await _emitted(
          container.read(offlinePinnedDocumentsProvider.future),
          'pinned documents',
        )).map((document) => document.id),
        expectedPinned.map((document) => document.id),
      );
      expect(
        (await _emitted(
          container.read(offlineBooksProvider.future),
          'books',
        )).map((document) => document.id),
        expectedBooks.map((document) => document.id),
      );
      expect(
        (await _emitted(
          container.read(offlineTagSystemsProvider.future),
          'tag systems',
        )).map((system) => system.name),
        expectedTags.map((system) => system.name),
      );

      expect(
        (await _emitted(
          container.read(offlineDocumentProvider(documentId).future),
          'document',
        ))?.id,
        documentId,
      );
    },
  );

  test('web policy saves editor changes directly to KGQL repository', () async {
    final repository = FakeDocumentRepository();
    final original = (await repository.listAll()).first;
    final container = ProviderContainer(
      overrides: [
        offlineEnabledProvider.overrideWithValue(false),
        documentRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(documentMutationControllerProvider)
        .saveDraft(
          original.copyWith(title: 'Saved directly on web'),
          policy: DraftSavePolicy.immediate,
        );

    expect(
      (await repository.getById(original.id))?.title,
      'Saved directly on web',
    );
    expect(container.read(offlineNotesServiceProvider), isNull);
  });

  test('web autosave does not refetch the catalog or open document', () async {
    final repository = _TrackingDocumentRepository();
    final original = (await repository.listAll()).first;
    final container = ProviderContainer(
      overrides: [
        offlineEnabledProvider.overrideWithValue(false),
        documentRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    final updatedDocument = Completer<NxDocument>();
    final subscriptions = [
      container.listen(offlineAllDocumentsProvider, (_, _) {}),
      container.listen(offlineDocumentProvider(original.id), (_, next) {
        final document = next.value;
        if (document?.title == 'Autosaved without refetch' &&
            !updatedDocument.isCompleted) {
          updatedDocument.complete(document);
        }
      }),
    ];
    addTearDown(() {
      for (final subscription in subscriptions) {
        subscription.close();
      }
    });
    await _emitted(
      container.read(offlineAllDocumentsProvider.future),
      'initial catalog',
    );
    await _emitted(
      container.read(offlineDocumentProvider(original.id).future),
      'initial document',
    );
    final catalogReadsBeforeSave = repository.listAllCalls;
    final documentReadsBeforeSave = repository.getByIdCalls;

    await container
        .read(documentMutationControllerProvider)
        .saveDraft(
          original.copyWith(title: 'Autosaved without refetch'),
          policy: DraftSavePolicy.immediate,
        );

    expect(repository.updateDraftCalls, 1);
    expect(repository.listAllCalls, catalogReadsBeforeSave);
    expect(repository.getByIdCalls, documentReadsBeforeSave);
    expect(
      (await updatedDocument.future.timeout(const Duration(seconds: 2))).title,
      'Autosaved without refetch',
    );
  });

  test('web catalog refreshes after a direct mutation', () async {
    final repository = FakeDocumentRepository();
    final container = ProviderContainer(
      overrides: [
        offlineEnabledProvider.overrideWithValue(false),
        documentRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      offlineAllDocumentsProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);
    await _emitted(
      container.read(offlineAllDocumentsProvider.future),
      'initial catalog',
    );

    final created = await container
        .read(documentMutationControllerProvider)
        .createDocument(title: 'Created directly on web');
    final refreshed = await _emitted(
      container.read(offlineAllDocumentsProvider.future),
      'refreshed catalog',
    );

    expect(
      refreshed.any(
        (document) =>
            document.id == created.id &&
            document.title == 'Created directly on web',
      ),
      isTrue,
    );
  });
}

Future<T> _emitted<T>(Future<T> future, String label) {
  return future.timeout(
    const Duration(seconds: 2),
    onTimeout: () => throw StateError('$label provider did not emit'),
  );
}

class _TrackingDocumentRepository extends FakeDocumentRepository {
  var listAllCalls = 0;
  var getByIdCalls = 0;
  var updateDraftCalls = 0;

  @override
  Future<List<NxDocument>> listAll() {
    listAllCalls++;
    return super.listAll();
  }

  @override
  Future<NxDocument?> getById(int id) {
    getByIdCalls++;
    return super.getById(id);
  }

  @override
  Future<NxDocument> updateDraft(NxDocument document) {
    updateDraftCalls++;
    return super.updateDraft(document);
  }
}
