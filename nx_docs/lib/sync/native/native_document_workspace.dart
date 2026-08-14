import 'dart:async';

import 'package:nx_docs/documents/document_session.dart';
import 'package:nx_docs/sync/native/background_uploader.dart';
import 'package:nx_docs/sync/native/native_document_session.dart';
import 'package:nx_docs/workspace/document_workspace.dart';
import 'package:nx_docs/sync/clock.dart';
import 'package:nx_docs/sync/id_generator.dart';
import 'package:nx_docs/sync/native/local_notes_store.dart';
import 'package:nx_docs/sync/remote/document_remote_api.dart';
import 'package:nx_docs/sync/document_synchronizer.dart';
import 'package:nx_docs/library/models/catalog_query.dart';
import 'package:nx_docs/library/models/catalog_state.dart';
import 'package:nx_docs/documents/document_models.dart';
import 'package:nx_docs/sync/sync_models.dart';
import 'package:nx_offline/nx_offline.dart' as offline;

final class NativeDocumentWorkspace implements DocumentWorkspace {
  NativeDocumentWorkspace({
    required LocalNotesStore localStore,
    required DocumentRemoteApi remoteApi,
    required BackgroundUploader uploader,
    required DocumentSynchronizer synchronizer,
    required Clock clock,
    required IdGenerator idGenerator,
  }) : _localStore = localStore,
       _remoteApi = remoteApi,
       _uploader = uploader,
       _synchronizer = synchronizer,
       _clock = clock,
       _idGenerator = idGenerator;

  final LocalNotesStore _localStore;
  final DocumentRemoteApi _remoteApi;
  final BackgroundUploader _uploader;
  final DocumentSynchronizer _synchronizer;
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
          () => _NativeCatalogFeed(query: query, localStore: _localStore),
        )
        .watch();
  }

  @override
  Future<void> refreshCatalog(CatalogQuery query) {
    if (_closed) return Future<void>.value();
    return syncLibrary();
  }

  @override
  DocumentSession openDocument(int documentId) {
    if (_closed) throw StateError('Notes workspace is closed');
    return _sessions.putIfAbsent(
      documentId,
      () => NativeDocumentSession(
        documentId: documentId,
        localStore: _localStore,
        synchronizer: _synchronizer,
        uploader: _uploader,
        clock: _clock,
        idGenerator: _idGenerator,
        onClosed: () => _sessions.remove(documentId),
      ),
    );
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
    return document;
  }

  @override
  Future<void> deleteDocument(int documentId) async {
    final existing = await _localStore.getDocumentByRemoteId(documentId);
    if (existing == null) {
      await _remoteApi.deleteDocument(documentId);
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

  @override
  Future<void> uploadPending() => _uploader.uploadPending();

  @override
  Future<void> syncLibrary({
    offline.SyncReason reason = offline.SyncReason.manual,
  }) {
    return _synchronizer.syncLibrary(reason: reason);
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await Future.wait(<Future<void>>[
      for (final session in _sessions.values.toList()) session.close(),
      for (final feed in _catalogs.values) feed.close(),
    ]);
    await _synchronizer.close();
    _sessions.clear();
    _catalogs.clear();
  }
}

final class _NativeCatalogFeed {
  _NativeCatalogFeed({required this.query, required LocalNotesStore localStore})
    : _localStore = localStore;

  final CatalogQuery query;
  final LocalNotesStore _localStore;
  final StreamController<CatalogState> _states =
      StreamController<CatalogState>.broadcast(sync: true);
  CatalogState _state = const CatalogState();
  StreamSubscription? _localSubscription;
  bool _started = false;
  bool _closed = false;

  Stream<CatalogState> watch() async* {
    if (!_started) {
      _started = true;
      final cached = await _localStore.readCatalog(query);
      _state = CatalogState(
        items: cached,
        isInitialLoading: false,
        isRefreshing: false,
      );
      _localSubscription = _localStore
          .watchCatalog(query)
          .listen(
            (items) {
              _emit(
                _state.copyWith(
                  items: items,
                  isInitialLoading: false,
                  isRefreshing: false,
                  clearError: true,
                ),
              );
            },
            onError: (Object error, StackTrace stackTrace) {
              _emit(_state.copyWith(error: error, isInitialLoading: false));
            },
          );
    }
    yield _state;
    yield* _states.stream;
  }

  Future<void> refresh() {
    return Future<void>.value();
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
