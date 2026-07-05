import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_notes/data/document/mirror_publish_trigger.dart';
import 'package:nx_notes/data/providers.dart';
import 'package:nx_notes/domain/document/document.dart';
import 'package:nx_notes/domain/document/document_publish.dart';
import 'package:nx_notes/domain/document/document_query.dart';
import 'package:nx_notes/domain/document/document_repository.dart';
import 'package:nx_notes/domain/document/document_snap.dart';
import 'package:nx_notes/domain/links/linked_model.dart';
import 'package:nx_notes/domain/tags/tag_system.dart';
import 'package:nx_notes/features/document/document_actions.dart';

void main() {
  test(
    'publish click saves publish json and triggers immediate publish',
    () async {
      final repository = _FakeDocumentRepository();
      final trigger = _FakeMirrorPublishTrigger();
      final container = ProviderContainer(
        overrides: [
          documentRepositoryProvider.overrideWithValue(repository),
          mirrorPublishTriggerProvider.overrideWithValue(trigger),
        ],
      );
      addTearDown(container.dispose);

      final document = _document(publish: DocumentPublishState.disabled());
      repository.nextUpdate = document;

      await container
          .read(documentMutationControllerProvider)
          .setPublishEnabled(document, true);
      await Future<void>.delayed(Duration.zero);

      expect(repository.updated, hasLength(2));
      expect(repository.updated.last.publish.enabled, true);
      expect(trigger.calls, [
        const _TriggerCall('publish_click', 3245, true, true),
      ]);
    },
  );

  test('published draft save triggers debounced edit publish', () async {
    final repository = _FakeDocumentRepository();
    final trigger = _FakeMirrorPublishTrigger();
    final container = ProviderContainer(
      overrides: [
        documentRepositoryProvider.overrideWithValue(repository),
        mirrorPublishTriggerProvider.overrideWithValue(trigger),
      ],
    );
    addTearDown(container.dispose);

    final document = _document(
      publish: DocumentPublishState.disabled().enable(
        jsonDocument: _jsonDocument('hello'),
        publishedAt: '2026-07-04T00:00:00Z',
        title: 'Doc',
        slug: 'doc',
      ),
    );

    await container
        .read(documentMutationControllerProvider)
        .saveDraft(document, policy: DraftSavePolicy.immediate);
    await Future<void>.delayed(Duration.zero);

    expect(repository.updated, hasLength(1));
    expect(trigger.calls, [const _TriggerCall('edit', 3245, false, false)]);
  });

  test('private draft save does not trigger publishing', () async {
    final repository = _FakeDocumentRepository();
    final trigger = _FakeMirrorPublishTrigger();
    final container = ProviderContainer(
      overrides: [
        documentRepositoryProvider.overrideWithValue(repository),
        mirrorPublishTriggerProvider.overrideWithValue(trigger),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(documentMutationControllerProvider)
        .saveDraft(
          _document(publish: DocumentPublishState.disabled()),
          policy: DraftSavePolicy.immediate,
        );
    await Future<void>.delayed(Duration.zero);

    expect(repository.updated, hasLength(1));
    expect(trigger.calls, isEmpty);
  });

  test(
    'publish click trigger failure fails after saving publish json',
    () async {
      final repository = _FakeDocumentRepository();
      final trigger = _FakeMirrorPublishTrigger(throwsOnTrigger: true);
      final container = ProviderContainer(
        overrides: [
          documentRepositoryProvider.overrideWithValue(repository),
          mirrorPublishTriggerProvider.overrideWithValue(trigger),
        ],
      );
      addTearDown(container.dispose);

      await expectLater(
        container
            .read(documentMutationControllerProvider)
            .setPublishEnabled(_document(), true),
        throwsStateError,
      );
      await Future<void>.delayed(Duration.zero);

      expect(repository.updated, hasLength(2));
      expect(trigger.calls, [
        const _TriggerCall('publish_click', 3245, true, true),
      ]);
    },
  );

  test('edit trigger failure does not fail document save', () async {
    final repository = _FakeDocumentRepository();
    final trigger = _FakeMirrorPublishTrigger(throwsOnTrigger: true);
    final container = ProviderContainer(
      overrides: [
        documentRepositoryProvider.overrideWithValue(repository),
        mirrorPublishTriggerProvider.overrideWithValue(trigger),
      ],
    );
    addTearDown(container.dispose);

    final document = _document(
      publish: DocumentPublishState.disabled().enable(
        jsonDocument: _jsonDocument('hello'),
        publishedAt: '2026-07-04T00:00:00Z',
        title: 'Doc',
        slug: 'doc',
      ),
    );

    await container
        .read(documentMutationControllerProvider)
        .saveDraft(document, policy: DraftSavePolicy.immediate);
    await Future<void>.delayed(Duration.zero);

    expect(repository.updated, hasLength(1));
    expect(trigger.calls, [const _TriggerCall('edit', 3245, false, false)]);
  });
}

NxDocument _document({DocumentPublishState? publish}) {
  return NxDocument(
    id: 3245,
    title: 'Doc',
    modelTypeName: 'Document',
    document: '',
    jsonDocument: _jsonDocument('hello'),
    wordCount: 1,
    status: '',
    topics: const [],
    areaTags: const [],
    tagsBySystem: const {},
    pinned: false,
    updatedAt: DateTime.utc(2026, 7, 4),
    updatedLabel: 'today',
    versionNumber: 1,
    excerpt: '',
    links: const [],
    publish: publish ?? DocumentPublishState.disabled(),
  );
}

Map<String, dynamic> _jsonDocument(String text) {
  return {
    'format': 'appflowy_document',
    'document': {
      'type': 'page',
      'children': [
        {
          'type': 'paragraph',
          'data': {
            'delta': [
              {'insert': text},
            ],
          },
        },
      ],
    },
  };
}

class _FakeMirrorPublishTrigger implements MirrorPublishTrigger {
  _FakeMirrorPublishTrigger({this.throwsOnTrigger = false});

  final bool throwsOnTrigger;
  final List<_TriggerCall> calls = [];

  @override
  Future<void> trigger({
    required String reason,
    required int documentId,
    required bool immediate,
    bool waitForCompletion = false,
  }) async {
    calls.add(_TriggerCall(reason, documentId, immediate, waitForCompletion));
    if (throwsOnTrigger) {
      throw StateError('boom');
    }
  }
}

class _TriggerCall {
  const _TriggerCall(
    this.reason,
    this.documentId,
    this.immediate,
    this.waitForCompletion,
  );

  final String reason;
  final int documentId;
  final bool immediate;
  final bool waitForCompletion;

  @override
  bool operator ==(Object other) {
    return other is _TriggerCall &&
        other.reason == reason &&
        other.documentId == documentId &&
        other.immediate == immediate &&
        other.waitForCompletion == waitForCompletion;
  }

  @override
  int get hashCode =>
      Object.hash(reason, documentId, immediate, waitForCompletion);

  @override
  String toString() {
    return '_TriggerCall($reason, $documentId, $immediate, $waitForCompletion)';
  }
}

class _FakeDocumentRepository implements DocumentRepository {
  final List<NxDocument> updated = [];
  NxDocument? nextUpdate;

  @override
  Future<NxDocument> updateDraft(NxDocument document) async {
    updated.add(document);
    return nextUpdate ?? document;
  }

  @override
  Future<void> attachLinkedModel({
    required int documentId,
    required LinkableModelType modelType,
    required int modelId,
  }) async {}

  @override
  Future<void> attachProject(int documentId, int projectId) async {}

  @override
  Future<NxDocument> create({
    String? title,
    DocumentKind kind = DocumentKind.document,
  }) async {
    return _document();
  }

  @override
  Future<DocumentSnap> createSnapshot(
    int documentId, {
    required String source,
    String changeSummary = '',
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> delete(int id) async {}

  @override
  Future<void> detachProject(int documentId, int relationId) async {}

  @override
  Future<NxDocument?> getById(int id) async => null;

  @override
  Future<List<NxDocument>> listBooks({int limit = 50}) async => [];

  @override
  Future<List<NxDocument>> listByTag(DocumentTagFilter filter) async => [];

  @override
  Future<List<NxDocument>> listPinned({int limit = 20}) async => [];

  @override
  Future<List<LinkedModel>> listProjects() async => [];

  @override
  Future<List<NxDocument>> listRecent({int limit = 20}) async => [];

  @override
  Future<List<DocumentSnap>> listSnapshots(int documentId) async => [];

  @override
  Future<List<TagSystem>> listTagSystems() async => [];

  @override
  Future<List<NxDocument>> search(String query) async => [];

  @override
  Future<List<LinkedModel>> searchLinkableModels({
    required LinkableModelType modelType,
    required String query,
  }) async {
    return [];
  }
}
