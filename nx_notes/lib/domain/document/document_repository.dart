import 'package:nx_notes/domain/document/document.dart';
import 'package:nx_notes/domain/document/document_query.dart';
import 'package:nx_notes/domain/document/document_snap.dart';
import 'package:nx_notes/domain/links/linked_model.dart';
import 'package:nx_notes/domain/tags/tag_system.dart';

abstract class DocumentRepository {
  Future<List<NxDocument>> listRecent({int limit = 20});
  Future<List<NxDocument>> listBooks({int limit = 50});
  Future<List<NxDocument>> listPinned({int limit = 20});
  Future<List<NxDocument>> search(String query);
  Future<List<NxDocument>> listByTag(DocumentTagFilter filter);
  Future<NxDocument?> getById(int id);
  Future<NxDocument> create({
    String? title,
    DocumentKind kind = DocumentKind.document,
  });
  Future<NxDocument> updateDraft(NxDocument document);
  Future<void> delete(int id);
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

enum DocumentKind {
  document('Document', 'Document'),
  book('Book', 'Book');

  const DocumentKind(this.modelTypeName, this.label);

  final String modelTypeName;
  final String label;
}
