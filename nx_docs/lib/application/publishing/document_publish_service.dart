import 'package:nx_docs/application/notes_workspace.dart';
import 'package:nx_docs/application/ports/clock.dart';
import 'package:nx_docs/application/ports/mirror_publish_trigger.dart';
import 'package:nx_docs/domain/document/document.dart';

final class DocumentPublishService {
  const DocumentPublishService({
    required NotesWorkspace workspace,
    required Clock clock,
    MirrorPublishTrigger? trigger,
  }) : _workspace = workspace,
       _clock = clock,
       _trigger = trigger;

  final NotesWorkspace _workspace;
  final Clock _clock;
  final MirrorPublishTrigger? _trigger;

  Future<NxDocument> setEnabled(NxDocument document, bool enabled) async {
    final now = _clock.now();
    final publish = enabled
        ? document.publish.enable(
            jsonDocument: document.jsonDocument,
            publishedAt: now.toUtc().toIso8601String(),
            tagsBySystem: document.publishTagsBySystem,
            title: document.title,
            slug: _slugForTitle(document.title, document.id),
          )
        : document.publish.disable();
    final updated = document.copyWith(
      publish: publish,
      updatedAt: now,
      updatedLabel: 'just now',
    );
    await _workspace.openDocument(updated.id).saveDraft(updated);
    await _workspace.uploadPending();
    await _trigger?.trigger(
      reason: 'publish_click',
      documentId: updated.id,
      immediate: true,
      waitForCompletion: true,
    );
    return updated;
  }

  Future<void> notifyEdit(NxDocument document) async {
    if (!document.publish.enabled) return;
    await _trigger?.trigger(
      reason: 'edit',
      documentId: document.id,
      immediate: false,
    );
  }
}

String _slugForTitle(String title, int id) {
  final slug = title
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return slug.isEmpty ? 'document-$id' : slug;
}
