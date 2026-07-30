import 'package:nx_notes/application/ports/notes_remote_api.dart';
import 'package:nx_notes/domain/catalog/catalog_query.dart';
import 'package:nx_notes/domain/document/document.dart';
import 'package:nx_notes/domain/document/document_summary.dart';
import 'package:nx_notes/domain/sync/document_sync.dart';
import 'package:nx_notes/domain/sync/remote_save_result.dart';

final class UnavailableNotesRemoteApi implements NotesRemoteApi {
  const UnavailableNotesRemoteApi();

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
