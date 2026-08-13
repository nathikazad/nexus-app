import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_docs/application/fake/fake_notes_workspace.dart';
import 'package:nx_docs/composition/notes_composition.dart';
import 'package:nx_docs/data/document/mirror_publish_trigger.dart';
import 'package:nx_docs/data/providers.dart';
import 'package:nx_docs/domain/document/document.dart';
import 'package:nx_docs/domain/document/document_publish.dart';
import 'package:nx_docs/features/document/document_actions.dart';

void main() {
  test(
    'publish click saves publish json and triggers immediate publish',
    () async {
      final trigger = _FakeMirrorPublishTrigger();
      final document = _document(publish: DocumentPublishState.disabled());
      final workspace = FakeNotesWorkspace(documents: [document]);
      final container = ProviderContainer(
        overrides: [
          notesWorkspaceProvider.overrideWithValue(workspace),
          mirrorPublishTriggerProvider.overrideWithValue(trigger),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(workspace.close);

      await container
          .read(documentMutationControllerProvider)
          .setPublishEnabled(document, true);
      await Future<void>.delayed(Duration.zero);

      expect(workspace.sessionFor(document.id)!.saveCount, 2);
      expect(
        workspace.sessionFor(document.id)!.state.document!.publish.enabled,
        true,
      );
      expect(trigger.calls, [
        const _TriggerCall('publish_click', 3245, true, true),
      ]);
    },
  );

  test('published draft save triggers debounced edit publish', () async {
    final trigger = _FakeMirrorPublishTrigger();
    final document = _document(
      publish: DocumentPublishState.disabled().enable(
        jsonDocument: _jsonDocument('hello'),
        publishedAt: '2026-07-04T00:00:00Z',
        title: 'Doc',
        slug: 'doc',
      ),
    );
    final workspace = FakeNotesWorkspace(documents: [document]);
    final container = ProviderContainer(
      overrides: [
        notesWorkspaceProvider.overrideWithValue(workspace),
        mirrorPublishTriggerProvider.overrideWithValue(trigger),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(workspace.close);

    await container
        .read(documentMutationControllerProvider)
        .saveDraft(document, policy: DraftSavePolicy.immediate);
    await Future<void>.delayed(Duration.zero);

    expect(workspace.sessionFor(document.id)!.saveCount, 1);
    expect(trigger.calls, [const _TriggerCall('edit', 3245, false, false)]);
  });

  test('private draft save does not trigger publishing', () async {
    final trigger = _FakeMirrorPublishTrigger();
    final document = _document(publish: DocumentPublishState.disabled());
    final workspace = FakeNotesWorkspace(documents: [document]);
    final container = ProviderContainer(
      overrides: [
        notesWorkspaceProvider.overrideWithValue(workspace),
        mirrorPublishTriggerProvider.overrideWithValue(trigger),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(workspace.close);

    await container
        .read(documentMutationControllerProvider)
        .saveDraft(document, policy: DraftSavePolicy.immediate);
    await Future<void>.delayed(Duration.zero);

    expect(workspace.sessionFor(document.id)!.saveCount, 1);
    expect(trigger.calls, isEmpty);
  });

  test(
    'publish click trigger failure fails after saving publish json',
    () async {
      final trigger = _FakeMirrorPublishTrigger(throwsOnTrigger: true);
      final document = _document();
      final workspace = FakeNotesWorkspace(documents: [document]);
      final container = ProviderContainer(
        overrides: [
          notesWorkspaceProvider.overrideWithValue(workspace),
          mirrorPublishTriggerProvider.overrideWithValue(trigger),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(workspace.close);

      await expectLater(
        container
            .read(documentMutationControllerProvider)
            .setPublishEnabled(document, true),
        throwsStateError,
      );
      await Future<void>.delayed(Duration.zero);

      expect(workspace.sessionFor(document.id)!.saveCount, 2);
      expect(trigger.calls, [
        const _TriggerCall('publish_click', 3245, true, true),
      ]);
    },
  );

  test('edit trigger failure does not fail document save', () async {
    final trigger = _FakeMirrorPublishTrigger(throwsOnTrigger: true);
    final document = _document(
      publish: DocumentPublishState.disabled().enable(
        jsonDocument: _jsonDocument('hello'),
        publishedAt: '2026-07-04T00:00:00Z',
        title: 'Doc',
        slug: 'doc',
      ),
    );
    final workspace = FakeNotesWorkspace(documents: [document]);
    final container = ProviderContainer(
      overrides: [
        notesWorkspaceProvider.overrideWithValue(workspace),
        mirrorPublishTriggerProvider.overrideWithValue(trigger),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(workspace.close);

    await container
        .read(documentMutationControllerProvider)
        .saveDraft(document, policy: DraftSavePolicy.immediate);
    await Future<void>.delayed(Duration.zero);

    expect(workspace.sessionFor(document.id)!.saveCount, 1);
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
