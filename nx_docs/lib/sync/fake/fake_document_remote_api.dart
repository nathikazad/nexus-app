import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:nx_docs/sync/remote/document_remote_api.dart';
import 'package:nx_docs/sync/remote/document_sync_transport.dart';
import 'package:nx_docs/library/models/catalog_query.dart';
import 'package:nx_docs/documents/document_models.dart';
import 'package:nx_docs/sync/sync_models.dart';

final class FakeDocumentRemoteApi
    implements DocumentRemoteApi, DocumentSyncTransport {
  FakeDocumentRemoteApi({
    Iterable<NxDocument> documents = const <NxDocument>[],
    this.error,
    this.catalogBarrier,
    this.documentBarrier,
    this.saveBarrier,
    this.syncBarrier,
  }) : _documents = <int, NxDocument>{
         for (final document in documents) document.id: document,
       };

  final Map<int, NxDocument> _documents;
  Object? error;
  Future<void>? catalogBarrier;
  Future<void>? documentBarrier;
  Future<void>? saveBarrier;
  Future<void>? syncBarrier;
  int catalogFetchCount = 0;
  final Map<int, int> documentFetchCounts = <int, int>{};
  int saveCount = 0;
  int syncCount = 0;
  final List<Set<int>?> syncScopes = <Set<int>?>[];
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
      CatalogKind.books => _limit(
        rows.where((document) => document.isBook),
        query.limit,
      ),
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
  Future<RemoteSaveResult> mutateDocument(NxDocument document) async {
    saveCount += 1;
    await saveBarrier;
    _throwIfConfigured();
    final current = _documents[document.id];
    if (current != null && !document.updatedAt.isAfter(current.updatedAt)) {
      return RemoteSaveResult(
        status: RemoteSaveStatus.stale,
        documentId: document.id,
        updatedAt: current.updatedAt,
        serverHash: _hash(current),
      );
    }
    _documents[document.id] = document;
    return RemoteSaveResult(
      status: RemoteSaveStatus.applied,
      documentId: document.id,
      updatedAt: document.updatedAt,
      serverHash: _hash(document),
    );
  }

  @override
  Future<DocumentSyncBundle> syncDocuments({
    required List<DocumentManifestEntry> manifest,
    Set<int>? documentIds,
  }) async {
    syncCount += 1;
    syncScopes.add(documentIds == null ? null : Set<int>.of(documentIds));
    await syncBarrier;
    _throwIfConfigured();
    final clientHashes = <int, String?>{
      for (final entry in manifest) entry.documentId: entry.serverHash,
    };
    final candidates =
        _documents.values
            .where(
              (document) =>
                  documentIds == null || documentIds.contains(document.id),
            )
            .toList()
          ..sort((a, b) => a.id.compareTo(b.id));
    return DocumentSyncBundle(
      documents: <RemoteDocument>[
        for (final document in candidates)
          if (clientHashes[document.id] != _hash(document))
            _remoteDocument(document),
      ],
      deletedIds: <int>[
        for (final entry in manifest)
          if ((documentIds == null || documentIds.contains(entry.documentId)) &&
              !_documents.containsKey(entry.documentId))
            entry.documentId,
      ],
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
  Future<RemoteSaveResult> deleteDocument(
    int documentId, {
    DateTime? clientUpdatedAt,
  }) async {
    _throwIfConfigured();
    final current = _documents[documentId];
    final editTime = clientUpdatedAt ?? DateTime.now().toUtc();
    if (current != null && !editTime.isAfter(current.updatedAt)) {
      return RemoteSaveResult(
        status: RemoteSaveStatus.stale,
        documentId: documentId,
        updatedAt: current.updatedAt,
        serverHash: _hash(current),
      );
    }
    _documents.remove(documentId);
    return RemoteSaveResult(
      status: RemoteSaveStatus.applied,
      documentId: documentId,
      updatedAt: editTime,
    );
  }

  RemoteDocument _remoteDocument(NxDocument document) {
    return RemoteDocument(
      key: DocumentKey(localId: 'remote-${document.id}', remoteId: document.id),
      document: document,
      revision: RemoteRevision(document.updatedAt.toUtc().toIso8601String()),
      serverHash: _hash(document),
    );
  }

  String _hash(NxDocument document) {
    return sha256
        .convert(
          utf8.encode(
            jsonEncode(<String, Object?>{
              'id': document.id,
              'title': document.title,
              'model_type': document.modelTypeName,
              'document': document.document,
              'json_document': document.jsonDocument,
              'pinned': document.pinned,
              'tags': document.tagsBySystem,
              'updated_at': document.updatedAt.toUtc().toIso8601String(),
            }),
          ),
        )
        .toString();
  }

  List<NxDocument> _limit(Iterable<NxDocument> rows, int? limit) {
    return (limit == null ? rows : rows.take(limit)).toList();
  }
}
