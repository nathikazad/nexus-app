import 'package:nx_notes/domain/catalog/catalog_query.dart';
import 'package:nx_notes/domain/document/document.dart';
import 'package:nx_notes/domain/document/document_summary.dart';
import 'package:nx_notes/domain/sync/remote_save_result.dart';

abstract interface class NotesRemoteApi {
  Future<List<DocumentSummary>> fetchCatalog(CatalogQuery query);

  Future<NxDocument?> fetchDocument(int documentId);

  Future<RemoteSaveResult> saveDocumentIfNewer(NxDocument document);

  Future<NxDocument> createDocument({
    String? title,
    DocumentKind kind = DocumentKind.document,
  });

  Future<void> deleteDocument(int documentId);
}
