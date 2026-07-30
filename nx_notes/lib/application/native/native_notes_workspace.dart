import 'dart:async';

import 'package:nx_notes/application/document_session.dart';
import 'package:nx_notes/application/native/background_uploader.dart';
import 'package:nx_notes/application/native/native_document_session.dart';
import 'package:nx_notes/application/notes_workspace.dart';
import 'package:nx_notes/application/ports/clock.dart';
import 'package:nx_notes/application/ports/id_generator.dart';
import 'package:nx_notes/application/ports/local_notes_store.dart';
import 'package:nx_notes/application/ports/notes_remote_api.dart';
import 'package:nx_notes/domain/catalog/catalog_query.dart';
import 'package:nx_notes/domain/catalog/catalog_state.dart';
import 'package:nx_notes/domain/document/document.dart';
import 'package:nx_notes/domain/document/document_identity.dart';
import 'package:nx_notes/domain/sync/document_revision.dart';
import 'package:nx_notes/domain/sync/pending_operation.dart';
import 'package:nx_notes/domain/sync/remote_document.dart';
import 'package:nx_notes/domain/sync/sync_state.dart';

final class NativeNotesWorkspace implements NotesWorkspace {
  NativeNotesWorkspace({
    required LocalNotesStore localStore,
    required NotesRemoteApi remoteApi,
    required BackgroundUploader uploader,
    required Clock clock,
    required IdGenerator idGenerator,
  }) : _localStore = localStore,
       _remoteApi = remoteApi,
       _uploader = uploader,
       _clock = clock,
       _idGenerator = idGenerator;

  final LocalNotesStore _localStore;
  final NotesRemoteApi _remoteApi;
  final BackgroundUploader _uploader;
  final Clock _clock;
  final IdGenerator _idGenerator;
  final Map<CatalogQuery, _NativeCatalogFeed> _catalogs =
      <CatalogQuery, _NativeCatalogFeed>{};
  final Map<int, NativeDocumentSession> _sessions =
      <int, NativeDocumentSession>{};
  bool _closed = false;

  @override
  Stream<CatalogState> watchCatalog(CatalogQuery query) {
    if (_closed) return const Stream<CatalogState>.empty();
    return _catalogs
        .putIfAbsent(
          query,
          () => _NativeCatalogFeed(
            query: query,
            localStore: _localStore,
            remoteApi: _remoteApi,
          ),
        )
        .watch();
  }

  @override
  Future<void> refreshCatalog(CatalogQuery query) {
    if (_closed) return Future<void>.value();
    return _catalogs
        .putIfAbsent(
          query,
          () => _NativeCatalogFeed(
            query: query,
            localStore: _localStore,
            remoteApi: _remoteApi,
          ),
        )
        .refresh();
  }

  @override
  DocumentSession openDocument(int documentId) {
    if (_closed) throw StateError('Notes workspace is closed');
    return _sessions.putIfAbsent(
      documentId,
      () => NativeDocumentSession(
        documentId: documentId,
        localStore: _localStore,
        remoteApi: _remoteApi,
        uploader: _uploader,
        clock: _clock,
        idGenerator: _idGenerator,
        onClosed: () => _sessions.remove(documentId),
      ),
    );
  }

  @override
  Future<NxDocument> createDocument({
    String? title,
    DocumentKind kind = DocumentKind.document,
  }) async {
    final document = await _remoteApi.createDocument(title: title, kind: kind);
    await _localStore.importRemoteDocuments(<RemoteDocument>[
      RemoteDocument(
        key: DocumentKey(
          localId: 'remote-${document.id}',
          remoteId: document.id,
        ),
        document: document,
        revision: RemoteRevision(document.updatedAt.toUtc().toIso8601String()),
      ),
    ]);
    await _refreshVisibleCatalogs();
    return document;
  }

  @override
  Future<void> deleteDocument(int documentId) async {
    final existing = await _localStore.getDocumentByRemoteId(documentId);
    if (existing == null) {
      await _remoteApi.deleteDocument(documentId);
      await _refreshVisibleCatalogs();
      return;
    }
    final now = _clock.now();
    await _localStore.saveDraftAndEnqueue(
      existing.copyWith(
        localUpdatedAt: now,
        syncState: DocumentSyncState.locallyModified,
        deletedLocally: true,
      ),
      operation: PendingOperation(
        operationId: _idGenerator.nextId(),
        accountKey: _localStore.accountKey,
        documentKey: existing.key,
        type: PendingOperationType.delete,
        payload: <String, Object?>{'document_id': documentId},
        baseRevision: existing.baseServerRevision,
        createdAt: now,
      ),
    );
    _uploader.schedule();
  }

  Future<void> _refreshVisibleCatalogs() async {
    await Future.wait(<Future<void>>[
      for (final feed in _catalogs.values) feed.refresh(),
    ]);
  }

  @override
  Future<void> uploadPending() => _uploader.uploadPending();

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

final class _NativeCatalogFeed {
  _NativeCatalogFeed({
    required this.query,
    required LocalNotesStore localStore,
    required NotesRemoteApi remoteApi,
  }) : _localStore = localStore,
       _remoteApi = remoteApi;

  final CatalogQuery query;
  final LocalNotesStore _localStore;
  final NotesRemoteApi _remoteApi;
  final StreamController<CatalogState> _states =
      StreamController<CatalogState>.broadcast(sync: true);
  CatalogState _state = const CatalogState();
  StreamSubscription? _localSubscription;
  Future<void>? _activeRefresh;
  bool _started = false;
  bool _closed = false;

  Stream<CatalogState> watch() async* {
    if (!_started) {
      _started = true;
      final cached = await _localStore.readCatalog(query);
      _state = CatalogState(
        items: cached,
        isInitialLoading: cached.isEmpty,
        isRefreshing: true,
      );
      _localSubscription = _localStore
          .watchCatalog(query)
          .listen(
            (items) {
              _emit(
                _state.copyWith(
                  items: items,
                  isInitialLoading: items.isEmpty && _state.isInitialLoading,
                  clearError: true,
                ),
              );
            },
            onError: (Object error, StackTrace stackTrace) {
              _emit(_state.copyWith(error: error, isInitialLoading: false));
            },
          );
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
    if (_closed) return;
    _emit(_state.copyWith(isRefreshing: true, clearError: true));
    try {
      final summaries = await _remoteApi.fetchCatalog(query);
      if (_closed) return;
      if (query.persistsMembership) {
        await _localStore.replaceCatalog(query, summaries);
        _emit(
          _state.copyWith(
            isInitialLoading: false,
            isRefreshing: false,
            clearError: true,
          ),
        );
      } else {
        _emit(
          CatalogState(
            items: summaries,
            isInitialLoading: false,
            isRefreshing: false,
          ),
        );
      }
    } catch (error) {
      if (_closed) return;
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
    await _localSubscription?.cancel();
    await _states.close();
  }
}
