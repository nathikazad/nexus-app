import 'package:nx_notes/application/notes_workspace.dart';
import 'package:nx_notes/domain/document/document.dart';
import 'package:nx_notes/domain/document/document_repository.dart';
import 'package:nx_notes/domain/document/document_snap.dart';

final class DocumentHistoryService {
  const DocumentHistoryService({
    required DocumentRepository repository,
    required NotesWorkspace workspace,
  }) : _repository = repository,
       _workspace = workspace;

  final DocumentRepository _repository;
  final NotesWorkspace _workspace;

  Future<List<DocumentSnap>> list(int documentId) {
    return _repository.listSnapshots(documentId);
  }

  Future<DocumentSnap> create(
    int documentId, {
    required String source,
    String changeSummary = '',
  }) {
    return _repository.createSnapshot(
      documentId,
      source: source,
      changeSummary: changeSummary,
    );
  }

  Future<void> restore(NxDocument document, DocumentSnap snapshot) async {
    await create(
      document.id,
      source: 'restore',
      changeSummary: 'Before restore to version ${snapshot.versionNumber}',
    );
    await _workspace
        .openDocument(document.id)
        .saveDraft(
          document.copyWith(
            document: snapshot.document,
            jsonDocument: snapshot.jsonDocument,
          ),
        );
    await _workspace.uploadPending();
  }
}
