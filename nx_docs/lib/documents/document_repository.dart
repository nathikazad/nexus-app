import 'package:nx_docs/documents/document_models.dart';
import 'package:nx_docs/tags/tag_system.dart';
import 'package:nx_docs/sync/sync_models.dart';

abstract class DocumentRepository {
  /// Returns the complete document library without a presentation limit.
  ///
  /// Offline hydration depends on this method and must never use a recent-list
  /// limit as a proxy for the full account library.
  Future<List<NxDocument>> listAll();

  Future<List<NxDocument>> listRecent({int limit = 20});
  Future<List<NxDocument>> listBooks({int? limit});
  Future<List<NxDocument>> listPinned({int limit = 20});
  Future<List<NxDocument>> search(String query);
  Future<List<NxDocument>> listByTag(DocumentTagFilter filter);
  Future<NxDocument?> getById(int id);
  Future<NxDocument> create({
    String? title,
    DocumentKind kind = DocumentKind.document,
  });
  Future<NxDocument> updateDraft(NxDocument document);
  Future<RemoteSaveResult> mutateDraft(NxDocument document);
  Future<RemoteSaveResult> delete(int id, {DateTime? clientUpdatedAt});
  Future<DocumentSnap> createSnapshot(
    int documentId, {
    required String source,
    String changeSummary = '',
  });
  Future<List<DocumentSnap>> listSnapshots(int documentId);
  Future<List<TagSystem>> listTagSystems();
  Future<List<LinkedModel>> listProjects();
  Future<List<LinkedModel>> searchLinkableModels({
    required LinkableModelType modelType,
    required String query,
  });
  Future<void> attachLinkedModel({
    required int documentId,
    required LinkableModelType modelType,
    required int modelId,
  });
  Future<void> attachProject(int documentId, int projectId);
  Future<void> detachProject(int documentId, int relationId);
}
