import 'package:nx_docs/sync/remote/document_sync_transport.dart';
import 'package:nx_docs/sync/remote/document_remote_api.dart';
import 'package:nx_docs/library/models/catalog_query.dart';
import 'package:nx_docs/documents/document_models.dart';
import 'package:nx_docs/documents/document_repository.dart';
import 'package:nx_docs/sync/sync_models.dart';

final class RepositoryDocumentRemoteApi implements DocumentRemoteApi {
  const RepositoryDocumentRemoteApi({
    required this.repository,
    required DocumentSyncTransport syncTransport,
  }) : _syncTransport = syncTransport;

  final DocumentRepository repository;
  final DocumentSyncTransport _syncTransport;

  @override
  Future<List<DocumentSummary>> fetchCatalog(CatalogQuery query) async {
    final documents = await switch (query.kind) {
      CatalogKind.all => repository.listAll(),
      CatalogKind.recent => repository.listRecent(limit: query.limit ?? 20),
      CatalogKind.pinned => repository.listPinned(limit: query.limit ?? 20),
      CatalogKind.books => repository.listBooks(limit: query.limit),
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
  Future<RemoteSaveResult> mutateDocument(NxDocument document) {
    return repository.mutateDraft(document);
  }

  @override
  Future<DocumentSyncBundle> syncDocuments({
    required List<DocumentManifestEntry> manifest,
    Set<int>? documentIds,
  }) {
    return _syncTransport.syncDocuments(
      manifest: manifest,
      documentIds: documentIds,
    );
  }

  @override
  Future<NxDocument> createDocument({
    String? title,
    DocumentKind kind = DocumentKind.document,
  }) {
    return repository.create(title: title, kind: kind);
  }

  @override
  Future<RemoteSaveResult> deleteDocument(
    int documentId, {
    DateTime? clientUpdatedAt,
  }) {
    return repository.delete(documentId, clientUpdatedAt: clientUpdatedAt);
  }
}
