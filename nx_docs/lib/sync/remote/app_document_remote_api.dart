import 'package:nx_db/app_reads.dart';
import 'package:nx_db/kgql.dart';
import 'package:nx_docs/documents/data/kgql/document_mapper.dart';
import 'package:nx_docs/documents/document_models.dart';
import 'package:nx_docs/library/models/catalog_query.dart';
import 'package:nx_docs/sync/sync_models.dart';
import 'document_remote_api.dart';

/// Screen reads share the backend app adapter; writes and offline reconciliation
/// remain on the mutation/sync contracts.
final class AppDocumentRemoteApi implements DocumentRemoteApi {
  AppDocumentRemoteApi(this.reads, this.mutations);
  final AppReads reads;
  final DocumentRemoteApi mutations;

  @override
  void invalidateReads() => reads.invalidate();

  @override
  Future<List<NxDocument>> fetchDocuments(Set<int> ids) async {
    if (ids.isEmpty) return [];
    final result = <NxDocument>[];
    final ordered = ids.toList()..sort();
    for (var offset = 0; offset < ordered.length; offset += 200) {
      final page = await reads.read('batch', {
        'ids': ordered.skip(offset).take(200).join(','),
      });
      result.addAll([
        for (final row in page['items'] as List)
          documentFromModel(
            Model.fromJson(Map<String, dynamic>.from(row as Map)),
          ),
      ]);
    }
    return result;
  }

  @override
  Future<List<DocumentSummary>> fetchCatalog(CatalogQuery query) async {
    final rows = await reads.items(
      limit: query.limit,
      query: {
        'kind': query.kind.name,
        if (query.searchText.isNotEmpty) 'search': query.searchText,
        if (query.tagFilter != null) 'tag_system': query.tagFilter!.system,
        if (query.tagFilter != null) 'tag': query.tagFilter!.node,
      },
    );
    return [
      for (final raw in rows)
        DocumentSummary.fromDocument(
          documentSummaryFromModel(
            Model.fromJson(Map<String, dynamic>.from(raw as Map)),
          ),
        ),
    ];
  }

  @override
  Future<NxDocument?> fetchDocument(int id) async {
    try {
      return documentFromModel(Model.fromJson(await reads.read('$id')));
    } on AppReadException catch (error) {
      if (error.statusCode == 404) return null;
      rethrow;
    }
  }

  @override
  Future<RemoteSaveResult> mutateDocument(NxDocument document) async {
    final result = await mutations.mutateDocument(document);
    reads.invalidate();
    return result;
  }

  @override
  Future<RemoteSaveResult> deleteDocument(
    int id, {
    DateTime? clientUpdatedAt,
  }) async {
    final result = await mutations.deleteDocument(
      id,
      clientUpdatedAt: clientUpdatedAt,
    );
    reads.invalidate();
    return result;
  }

  @override
  Future<NxDocument> createDocument({
    String? title,
    DocumentKind kind = DocumentKind.document,
  }) async {
    final result = await mutations.createDocument(title: title, kind: kind);
    reads.invalidate();
    return result;
  }

  @override
  Future<DocumentSyncBundle> syncDocuments({
    required List<DocumentManifestEntry> manifest,
    Set<int>? documentIds,
    bool manifestOnly = false,
  }) => mutations.syncDocuments(
    manifest: manifest,
    documentIds: documentIds,
    manifestOnly: manifestOnly,
  );
}
