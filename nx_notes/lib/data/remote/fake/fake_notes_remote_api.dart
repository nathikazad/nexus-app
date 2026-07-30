import 'package:nx_notes/application/ports/notes_remote_api.dart';
import 'package:nx_notes/domain/catalog/catalog_query.dart';
import 'package:nx_notes/domain/document/document.dart';
import 'package:nx_notes/domain/document/document_summary.dart';
import 'package:nx_notes/domain/sync/remote_save_result.dart';

final class FakeNotesRemoteApi implements NotesRemoteApi {
  FakeNotesRemoteApi({
    Iterable<NxDocument> documents = const <NxDocument>[],
    this.error,
    this.catalogBarrier,
    this.documentBarrier,
    this.saveBarrier,
  }) : _documents = <int, NxDocument>{
         for (final document in documents) document.id: document,
       };

  final Map<int, NxDocument> _documents;
  Object? error;
  Future<void>? catalogBarrier;
  Future<void>? documentBarrier;
  Future<void>? saveBarrier;
  int catalogFetchCount = 0;
  final Map<int, int> documentFetchCounts = <int, int>{};
  int saveCount = 0;
  int _nextId = 10000;

  List<NxDocument> get documents => _documents.values.toList(growable: false);

  void replaceRemote(NxDocument document) {
    _documents[document.id] = document;
  }

  void _throwIfConfigured() {
    final configured = error;
    if (configured != null) throw configured;
  }

  @override
  Future<List<DocumentSummary>> fetchCatalog(CatalogQuery query) async {
    catalogFetchCount += 1;
    await catalogBarrier;
    _throwIfConfigured();
    var rows = _documents.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    rows = switch (query.kind) {
      CatalogKind.all => rows,
      CatalogKind.recent => rows.take(query.limit ?? 20).toList(),
      CatalogKind.pinned =>
        rows
            .where((document) => document.pinned)
            .take(query.limit ?? 20)
            .toList(),
      CatalogKind.books =>
        rows
            .where((document) => document.isBook)
            .take(query.limit ?? 100)
            .toList(),
      CatalogKind.search =>
        rows
            .where(
              (document) => <String>[document.title, document.excerpt]
                  .join(' ')
                  .toLowerCase()
                  .contains(query.searchText.trim().toLowerCase()),
            )
            .toList(),
      CatalogKind.tag =>
        rows
            .where(
              (document) =>
                  document.tagsBySystem[query.tagFilter!.system]?.contains(
                    query.tagFilter!.node,
                  ) ??
                  false,
            )
            .toList(),
    };
    return rows.map(DocumentSummary.fromDocument).toList(growable: false);
  }

  @override
  Future<NxDocument?> fetchDocument(int documentId) async {
    documentFetchCounts.update(
      documentId,
      (count) => count + 1,
      ifAbsent: () => 1,
    );
    await documentBarrier;
    _throwIfConfigured();
    return _documents[documentId];
  }

  @override
  Future<RemoteSaveResult> saveDocumentIfNewer(NxDocument document) async {
    saveCount += 1;
    await saveBarrier;
    _throwIfConfigured();
    final current = _documents[document.id];
    if (current != null && !document.updatedAt.isAfter(current.updatedAt)) {
      return RemoteSaveResult(
        status: RemoteSaveStatus.stale,
        documentId: document.id,
        updatedAt: current.updatedAt,
      );
    }
    _documents[document.id] = document;
    return RemoteSaveResult(
      status: RemoteSaveStatus.applied,
      documentId: document.id,
      updatedAt: document.updatedAt,
    );
  }

  @override
  Future<NxDocument> createDocument({
    String? title,
    DocumentKind kind = DocumentKind.document,
  }) async {
    _throwIfConfigured();
    final now = DateTime.now().toUtc();
    final id = _nextId++;
    final document = NxDocument(
      id: id,
      title: title?.trim().isNotEmpty == true
          ? title!.trim()
          : 'Untitled document',
      modelTypeName: kind.modelTypeName,
      document: '',
      jsonDocument: const <String, dynamic>{
        'format': 'appflowy_document',
        'document': <String, dynamic>{'type': 'page', 'children': <Object>[]},
      },
      wordCount: 0,
      status: 'Draft',
      topics: const <String>[],
      areaTags: const <String>[],
      tagsBySystem: const <String, List<String>>{},
      pinned: false,
      updatedAt: now,
      updatedLabel: 'just now',
      versionNumber: 0,
      excerpt: '',
      links: const [],
      readingState: kind == DocumentKind.book ? 'to_read' : '',
    );
    _documents[id] = document;
    return document;
  }

  @override
  Future<void> deleteDocument(int documentId) async {
    _throwIfConfigured();
    _documents.remove(documentId);
  }
}
