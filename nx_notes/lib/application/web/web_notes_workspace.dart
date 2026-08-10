import 'dart:async';

import 'package:nx_notes/application/document_session.dart';
import 'package:nx_notes/application/notes_workspace.dart';
import 'package:nx_notes/application/ports/notes_remote_api.dart';
import 'package:nx_notes/application/web/web_document_session.dart';
import 'package:nx_notes/domain/catalog/catalog_query.dart';
import 'package:nx_notes/domain/catalog/catalog_state.dart';
import 'package:nx_notes/domain/document/document.dart';

final class WebNotesWorkspace implements NotesWorkspace {
  WebNotesWorkspace({required NotesRemoteApi remoteApi})
    : _remoteApi = remoteApi;

  final NotesRemoteApi _remoteApi;
  final Map<CatalogQuery, _WebCatalogFeed> _catalogs =
      <CatalogQuery, _WebCatalogFeed>{};
  final Map<int, WebDocumentSession> _sessions = <int, WebDocumentSession>{};
  bool _closed = false;

  @override
  Stream<CatalogState> watchCatalog(CatalogQuery query) {
    return _catalogs
        .putIfAbsent(
          query,
          () => _WebCatalogFeed(query: query, remoteApi: _remoteApi),
        )
        .watch();
  }

  @override
  Future<void> refreshCatalog(CatalogQuery query) {
    return _catalogs
        .putIfAbsent(
          query,
          () => _WebCatalogFeed(query: query, remoteApi: _remoteApi),
        )
        .refresh();
  }

  @override
  DocumentSession openDocument(int documentId) {
    if (_closed) throw StateError('Notes workspace is closed');
    return _sessions.putIfAbsent(
      documentId,
      () => WebDocumentSession(
        documentId: documentId,
        remoteApi: _remoteApi,
        onClosed: () => _sessions.remove(documentId),
      ),
    );
  }

  @override
  Future<NxDocument> createDocument({
    String? title,
    DocumentKind kind = DocumentKind.document,
  }) async {
    final created = await _remoteApi.createDocument(title: title, kind: kind);
    await _refreshVisibleCatalogs();
    return created;
  }

  @override
  Future<void> deleteDocument(int documentId) async {
    await _remoteApi.deleteDocument(documentId);
    await _refreshVisibleCatalogs();
  }

  Future<void> _refreshVisibleCatalogs() {
    return Future.wait(<Future<void>>[
      for (final feed in _catalogs.values) feed.refresh(),
    ]);
  }

  @override
  Future<void> uploadPending() async {}

  @override
  Future<void> syncLibrary() {
    return Future.wait(<Future<void>>[
      for (final query in libraryCatalogQueries) refreshCatalog(query),
    ]);
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await Future.wait(<Future<void>>[
      for (final session in _sessions.values.toList()) session.close(),
      for (final feed in _catalogs.values) feed.close(),
    ]);
    _sessions.clear();
    _catalogs.clear();
  }
}

final class _WebCatalogFeed {
  _WebCatalogFeed({required this.query, required NotesRemoteApi remoteApi})
    : _remoteApi = remoteApi;

  final CatalogQuery query;
  final NotesRemoteApi _remoteApi;
  final StreamController<CatalogState> _states =
      StreamController<CatalogState>.broadcast(sync: true);
  CatalogState _state = const CatalogState();
  Future<void>? _activeRefresh;
  bool _started = false;
  bool _closed = false;

  Stream<CatalogState> watch() async* {
    if (!_started) {
      _started = true;
      unawaited(refresh());
    }
    yield _state;
    yield* _states.stream;
  }

  Future<void> refresh() {
    final active = _activeRefresh;
    if (active != null) return active;
    final run = _refresh();
    _activeRefresh = run;
    return run.whenComplete(() {
      if (identical(_activeRefresh, run)) _activeRefresh = null;
    });
  }

  Future<void> _refresh() async {
    _emit(_state.copyWith(isRefreshing: true, clearError: true));
    try {
      final items = await _remoteApi.fetchCatalog(query);
      _emit(
        CatalogState(
          items: items,
          isInitialLoading: false,
          isRefreshing: false,
        ),
      );
    } catch (error) {
      _emit(
        _state.copyWith(
          isInitialLoading: false,
          isRefreshing: false,
          error: error,
        ),
      );
    }
  }

  void _emit(CatalogState next) {
    _state = next;
    if (!_closed) _states.add(next);
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _states.close();
  }
}
