import 'package:nx_docs/library/models/catalog_query.dart';
import 'package:nx_docs/documents/document_models.dart';
import 'package:nx_docs/sync/sync_models.dart';

abstract interface class DocumentRemoteApi {
  Future<List<DocumentSummary>> fetchCatalog(CatalogQuery query);

  Future<NxDocument?> fetchDocument(int documentId);

  Future<RemoteSaveResult> mutateDocument(NxDocument document);

  Future<DocumentSyncBundle> syncDocuments({
    required List<DocumentManifestEntry> manifest,
    Set<int>? documentIds,
  });

  Future<NxDocument> createDocument({
    String? title,
    DocumentKind kind = DocumentKind.document,
  });

  Future<RemoteSaveResult> deleteDocument(
    int documentId, {
    DateTime? clientUpdatedAt,
  });
}
