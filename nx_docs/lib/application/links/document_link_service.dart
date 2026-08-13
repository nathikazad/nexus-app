import 'package:nx_docs/application/notes_workspace.dart';
import 'package:nx_docs/domain/document/document_repository.dart';
import 'package:nx_docs/domain/links/linked_model.dart';

final class DocumentLinkService {
  const DocumentLinkService({
    required DocumentRepository repository,
    required NotesWorkspace workspace,
  }) : _repository = repository,
       _workspace = workspace;

  final DocumentRepository _repository;
  final NotesWorkspace _workspace;

  Future<List<LinkedModel>> projects() => _repository.listProjects();

  Future<List<LinkedModel>> search({
    required LinkableModelType modelType,
    required String query,
  }) {
    return _repository.searchLinkableModels(modelType: modelType, query: query);
  }

  Future<void> attach({
    required int documentId,
    required LinkableModelType modelType,
    required int modelId,
  }) async {
    await _repository.attachLinkedModel(
      documentId: documentId,
      modelType: modelType,
      modelId: modelId,
    );
    await _workspace.openDocument(documentId).refresh();
  }

  Future<void> attachProject(int documentId, int projectId) async {
    await _repository.attachProject(documentId, projectId);
    await _workspace.openDocument(documentId).refresh();
  }

  Future<void> detachProject(int documentId, int relationId) async {
    await _repository.detachProject(documentId, relationId);
    await _workspace.openDocument(documentId).refresh();
  }
}
