import 'package:nx_notes/application/ports/notes_remote_api.dart';
import 'package:nx_notes/domain/catalog/catalog_query.dart';
import 'package:nx_notes/domain/document/document.dart';
import 'package:nx_notes/domain/document/document_repository.dart';
import 'package:nx_notes/domain/document/document_summary.dart';
import 'package:nx_notes/domain/sync/remote_save_result.dart';

final class RepositoryNotesRemoteApi implements NotesRemoteApi {
  const RepositoryNotesRemoteApi(this.repository);

  final DocumentRepository repository;

  @override
  Future<List<DocumentSummary>> fetchCatalog(CatalogQuery query) async {
    final documents = await switch (query.kind) {
      CatalogKind.all => repository.listAll(),
      CatalogKind.recent => repository.listRecent(limit: query.limit ?? 20),
      CatalogKind.pinned => repository.listPinned(limit: query.limit ?? 20),
      CatalogKind.books => repository.listBooks(limit: query.limit ?? 100),
      CatalogKind.search => repository.search(query.searchText),
      CatalogKind.tag => repository.listByTag(query.tagFilter!),
    };
    return documents.map(DocumentSummary.fromDocument).toList(growable: false);
  }

  @override
  Future<NxDocument?> fetchDocument(int documentId) {
    return repository.getById(documentId);
  }

  @override
  Future<RemoteSaveResult> saveDocumentIfNewer(NxDocument document) {
    return repository.saveDraftIfNewer(document);
  }

  @override
  Future<NxDocument> createDocument({
    String? title,
    DocumentKind kind = DocumentKind.document,
  }) {
    return repository.create(title: title, kind: kind);
  }

  @override
  Future<void> deleteDocument(int documentId) {
    return repository.delete(documentId);
  }
}
