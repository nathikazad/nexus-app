import 'package:nx_db/app_reads.dart';
import 'package:nx_db/kgql.dart';
import 'package:nx_docs/documents/data/kgql/document_mapper.dart';
import 'package:nx_docs/documents/document_models.dart';
import 'package:nx_docs/library/models/catalog_query.dart';
import 'package:nx_docs/sync/sync_models.dart';
import 'package:nx_docs/sync/remote/document_remote_api.dart';

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
    if (query.limit != null && query.limit! <= 0) return [];
    final documents = <DocumentSummary>[];
    String? cursor;
    do {
      final page = await reads.read('items', {
        'kind': query.kind.name,
        'limit': '50',
        if (cursor != null) 'cursor': cursor,
        if (query.searchText.isNotEmpty) 'search': query.searchText,
        if (query.tagFilter != null) 'tag_system': query.tagFilter!.system,
        if (query.tagFilter != null) 'tag': query.tagFilter!.node,
      });
      for (final raw in page['items'] as List) {
        final document = documentSummaryFromModel(
          Model.fromJson(Map<String, dynamic>.from(raw as Map)),
        );
        if (query.kind == CatalogKind.books || !document.isBookContent) {
          documents.add(DocumentSummary.fromDocument(document));
        }
      }
      final next = page['next_cursor'] as String?;
      if (next != null && next == cursor) {
        throw StateError('Page did not advance');
      }
      cursor = next;
    } while (cursor != null &&
        (query.limit == null || documents.length < query.limit!));
    return query.limit == null
        ? documents
        : documents.take(query.limit!).toList();
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
