import 'package:nx_docs/sync/remote/document_remote_api.dart';
import 'package:nx_docs/library/models/catalog_query.dart';
import 'package:nx_docs/documents/document_models.dart';
import 'package:nx_docs/sync/sync_models.dart';

final class UnavailableDocumentRemoteApi implements DocumentRemoteApi {
  const UnavailableDocumentRemoteApi();

  Never _unavailable() {
    throw StateError('The remote notes service is unavailable while offline.');
  }

  @override
  Future<List<DocumentSummary>> fetchCatalog(CatalogQuery query) async =>
      _unavailable();

  @override
  Future<NxDocument?> fetchDocument(int documentId) async => _unavailable();

  @override
  Future<RemoteSaveResult> mutateDocument(NxDocument document) async =>
      _unavailable();

  @override
  Future<DocumentSyncBundle> syncDocuments({
    required List<DocumentManifestEntry> manifest,
    Set<int>? documentIds,
  }) async => _unavailable();

  @override
  Future<NxDocument> createDocument({
    String? title,
    DocumentKind kind = DocumentKind.document,
  }) async => _unavailable();

  @override
  Future<RemoteSaveResult> deleteDocument(
    int documentId, {
    DateTime? clientUpdatedAt,
  }) async => _unavailable();
}
