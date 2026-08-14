import 'dart:async';

import 'package:nx_docs/documents/document_session.dart';
import 'package:nx_docs/workspace/document_workspace.dart';
import 'package:nx_docs/library/models/catalog_query.dart';
import 'package:nx_docs/library/models/catalog_state.dart';
import 'package:nx_docs/documents/document_models.dart';
import 'package:nx_offline/nx_offline.dart' as offline;

final class FakeDocumentWorkspace implements DocumentWorkspace {
  FakeDocumentWorkspace({Iterable<NxDocument> documents = const <NxDocument>[]})
    : _documents = <int, NxDocument>{
        for (final document in documents) document.id: document,
      };

  final Map<int, NxDocument> _documents;
  final Map<int, FakeDocumentSession> _sessions = <int, FakeDocumentSession>{};
  final StreamController<void> _changes = StreamController<void>.broadcast(
    sync: true,
  );
  int openCount = 0;
  int refreshCount = 0;
  int uploadCount = 0;
  int _nextId = 10000;

  FakeDocumentSession? sessionFor(int id) => _sessions[id];

  @override
  Stream<CatalogState> watchCatalog(CatalogQuery query) async* {
    yield _catalog(query);
    await for (final _ in _changes.stream) {
      yield _catalog(query);
    }
  }

  CatalogState _catalog(CatalogQuery query) {
    var documents = _documents.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    documents = switch (query.kind) {
      CatalogKind.all => documents,
      CatalogKind.recent => documents.take(query.limit ?? 20).toList(),
      CatalogKind.pinned =>
        documents
            .where((document) => document.pinned)
            .take(query.limit ?? 20)
            .toList(),
      CatalogKind.books =>
        documents
            .where((document) => document.isBook)
            .take(query.limit ?? 100)
            .toList(),
      CatalogKind.search =>
        documents
            .where(
              (document) => document.title.toLowerCase().contains(
                query.searchText.trim().toLowerCase(),
              ),
            )
            .toList(),
      CatalogKind.tag =>
        documents
            .where(
              (document) =>
                  document.tagsBySystem[query.tagFilter!.system]?.contains(
                    query.tagFilter!.node,
                  ) ??
                  false,
            )
            .toList(),
    };
    return CatalogState(
      items: documents
          .map(DocumentSummary.fromDocument)
          .toList(growable: false),
      isInitialLoading: false,
    );
  }

  @override
  Future<void> refreshCatalog(CatalogQuery query) async {
    refreshCount += 1;
    _changes.add(null);
  }

  @override
  DocumentSession openDocument(int documentId) {
    return _sessions.putIfAbsent(documentId, () {
      openCount += 1;
      return FakeDocumentSession(
        documentId: documentId,
        initialDocument: _documents[documentId],
        onSaved: (document) {
          _documents[document.id] = document;
          _changes.add(null);
        },
        onClosed: () => _sessions.remove(documentId),
      );
    });
  }

  @override
  Future<void> ensureDocumentAvailable(int documentId) {
    return openDocument(documentId).refresh();
  }

  @override
  Future<NxDocument> createDocument({
    String? title,
    DocumentKind kind = DocumentKind.document,
  }) async {
    final existing = _documents.values.firstOrNull;
    if (existing == null) {
      throw StateError('Seed one fake document before creating another');
    }
    final created = existing.copyWith(
      title: title ?? 'Untitled document',
      modelTypeName: kind.modelTypeName,
      updatedAt: DateTime.now().toUtc(),
    );
    final withId = NxDocument(
      id: _nextId++,
      title: created.title,
      modelTypeName: created.modelTypeName,
      document: created.document,
      jsonDocument: created.jsonDocument,
      wordCount: created.wordCount,
      status: created.status,
      topics: created.topics,
      areaTags: created.areaTags,
      tagsBySystem: created.tagsBySystem,
      pinned: created.pinned,
      updatedAt: created.updatedAt,
      updatedLabel: created.updatedLabel,
      versionNumber: created.versionNumber,
      excerpt: created.excerpt,
      links: created.links,
      publish: created.publish,
      readingState: created.readingState,
      bookRank: created.bookRank,
    );
    _documents[withId.id] = withId;
    _changes.add(null);
    return withId;
  }

  @override
  Future<void> deleteDocument(int documentId) async {
    _documents.remove(documentId);
    _changes.add(null);
  }

  @override
  Future<void> uploadPending() async {
    uploadCount += 1;
  }

  @override
  Future<void> syncLibrary({
    offline.SyncReason reason = offline.SyncReason.manual,
  }) async {
    uploadCount += 1;
  }

  @override
  Future<void> close() async {
    await Future.wait(<Future<void>>[
      for (final session in _sessions.values.toList()) session.close(),
    ]);
    await _changes.close();
  }
}

final class FakeDocumentSession implements DocumentSession {
  FakeDocumentSession({
    required this.documentId,
    required NxDocument? initialDocument,
    required void Function(NxDocument document) onSaved,
    required void Function() onClosed,
  }) : _onSaved = onSaved,
       _onClosed = onClosed,
       _state = DocumentSessionState(
         phase: initialDocument == null
             ? DocumentPhase.notFound
             : DocumentPhase.ready,
         document: initialDocument,
       );

  @override
  final int documentId;
  final void Function(NxDocument document) _onSaved;
  final void Function() _onClosed;
  final StreamController<DocumentSessionState> _states =
      StreamController<DocumentSessionState>.broadcast(sync: true);
  DocumentSessionState _state;
  int refreshCount = 0;
  int saveCount = 0;
  bool _closed = false;

  @override
  DocumentSessionState get state => _state;

  @override
  Stream<DocumentSessionState> get states => _states.stream;

  void replaceDocument(
    NxDocument document, {
    DocumentChangeOrigin origin = DocumentChangeOrigin.remoteRefresh,
  }) {
    _emit(
      _state.copyWith(
        phase: DocumentPhase.ready,
        document: document,
        origin: origin,
      ),
    );
  }

  @override
  Future<void> refresh() async {
    refreshCount += 1;
  }

  @override
  Future<void> saveDraft(NxDocument document) async {
    saveCount += 1;
    _onSaved(document);
    _emit(
      _state.copyWith(
        phase: DocumentPhase.ready,
        document: document,
        origin: DocumentChangeOrigin.user,
      ),
    );
  }

  @override
  Future<void> setPinned(bool pinned) async {
    final document = _state.document;
    if (document == null) {
      throw StateError('Document $documentId is not ready');
    }
    await saveDraft(document.copyWith(pinned: pinned));
  }

  void _emit(DocumentSessionState state) {
    _state = state;
    if (!_closed) _states.add(state);
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _states.close();
    _onClosed();
  }
}
