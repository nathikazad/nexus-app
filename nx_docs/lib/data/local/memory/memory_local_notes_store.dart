import 'dart:async';

import 'package:nx_docs/application/ports/local_notes_store.dart';
import 'package:nx_docs/application/sync/outbox_coalescer.dart';
import 'package:nx_docs/domain/catalog/catalog_query.dart';
import 'package:nx_docs/domain/document/document.dart';
import 'package:nx_docs/domain/document/document_identity.dart';
import 'package:nx_docs/domain/document/document_summary.dart';
import 'package:nx_docs/domain/sync/local_document.dart';
import 'package:nx_docs/domain/sync/document_sync.dart';
import 'package:nx_docs/domain/sync/pending_operation.dart';
import 'package:nx_docs/domain/sync/remote_document.dart';
import 'package:nx_docs/domain/sync/sync_failure.dart';
import 'package:nx_docs/domain/sync/sync_state.dart';

class MemoryLocalNotesStore implements LocalNotesStore {
  MemoryLocalNotesStore({
    required this.accountKey,
    this.coalescer = const OutboxCoalescer(),
  });

  @override
  final String accountKey;
  final OutboxCoalescer coalescer;
  final Map<String, LocalDocument> _documents = <String, LocalDocument>{};
  final Map<int, DocumentSummary> _summaries = <int, DocumentSummary>{};
  final Set<int> _deletedSummaryIds = <int>{};
  final Map<String, PendingOperation> _operations =
      <String, PendingOperation>{};
  final StreamController<void> _changes = StreamController<void>.broadcast();
  final Map<String, List<int>> _catalogs = <String, List<int>>{};
  bool _disposed = false;

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _changes.close();
  }

  @override
  Future<LocalDocument?> getDocument(DocumentKey key) async {
    return _documents[key.localId];
  }

  @override
  Future<LocalDocument?> getDocumentByRemoteId(int remoteId) async {
    for (final document in _documents.values) {
      if (document.key.remoteId == remoteId) return document;
    }
    return null;
  }

  @override
  Stream<LocalDocument?> watchDocument(DocumentKey key) {
    return _watch(() => _documents[key.localId]);
  }

  @override
  Stream<List<DocumentSummary>> watchCatalog(CatalogQuery query) {
    if (!query.persistsMembership) {
      return _watch(() => _filterSummaries(_visibleSummaries(), query));
    }
    return _watch(() {
      final ids = _catalogs[query.cacheKey] ?? const <int>[];
      return <DocumentSummary>[
        for (final id in ids)
          if (!_deletedSummaryIds.contains(id))
            if (_summaries[id] case final summary?) summary,
      ];
    });
  }

  @override
  Future<List<DocumentSummary>> readCatalog(CatalogQuery query) {
    if (!query.persistsMembership) {
      return Future<List<DocumentSummary>>.value(
        _filterSummaries(_visibleSummaries(), query),
      );
    }
    final ids = _catalogs[query.cacheKey] ?? const <int>[];
    return Future<List<DocumentSummary>>.value(<DocumentSummary>[
      for (final id in ids)
        if (!_deletedSummaryIds.contains(id))
          if (_summaries[id] case final summary?) summary,
    ]);
  }

  @override
  Future<void> replaceCatalog(
    CatalogQuery query,
    List<DocumentSummary> summaries,
  ) async {
    if (!query.persistsMembership) return;
    final ids = <int>[];
    for (final summary in summaries) {
      final remoteId = summary.id;
      ids.add(remoteId);
      final existing = _documentByRemoteId(remoteId);
      if (existing == null || existing.syncState == DocumentSyncState.synced) {
        _summaries[remoteId] = summary;
        _deletedSummaryIds.remove(remoteId);
      }
    }
    _catalogs[query.cacheKey] = ids;
    _notify();
  }

  @override
  Future<void> importRemoteDocuments(List<RemoteDocument> documents) async {
    var changed = false;
    for (final remote in documents) {
      final existing = _documents[remote.key.localId];
      if (existing != null && existing.syncState != DocumentSyncState.synced) {
        continue;
      }
      _documents[remote.key.localId] = LocalDocument(
        key: remote.key,
        accountKey: accountKey,
        document: remote.document,
        localUpdatedAt: remote.document.updatedAt,
        serverRevision: remote.revision,
        baseServerRevision: remote.revision,
        serverHash: remote.serverHash,
        syncState: DocumentSyncState.synced,
        deletedLocally: remote.deleted,
      );
      _storeSummary(remote.document, deleted: remote.deleted);
      changed = true;
    }
    if (changed) {
      _rebuildDefaultCatalogs();
      _notify();
    }
  }

  @override
  Future<List<DocumentManifestEntry>> documentManifest() async {
    final documents =
        _documents.values
            .where(
              (document) =>
                  document.key.remoteId != null && !document.deletedLocally,
            )
            .toList()
          ..sort((a, b) => a.key.remoteId!.compareTo(b.key.remoteId!));
    return <DocumentManifestEntry>[
      for (final document in documents)
        DocumentManifestEntry(
          documentId: document.key.remoteId!,
          serverHash: document.serverHash,
        ),
    ];
  }

  @override
  Future<void> applySyncBundle(DocumentSyncBundle bundle) async {
    for (final remote in bundle.documents) {
      final remoteId = remote.key.remoteId;
      if (remoteId == null) continue;
      final existing = _documentByRemoteId(remoteId);
      if (existing != null && existing.syncState != DocumentSyncState.synced) {
        continue;
      }
      final key = existing?.key ?? remote.key;
      _documents[key.localId] = LocalDocument(
        key: key,
        accountKey: accountKey,
        document: remote.document,
        localUpdatedAt: remote.document.updatedAt,
        serverRevision: remote.revision,
        baseServerRevision: remote.revision,
        serverHash: remote.serverHash,
        syncState: DocumentSyncState.synced,
      );
      _storeSummary(remote.document);
    }
    for (final remoteId in bundle.deletedIds) {
      final existing = _documentByRemoteId(remoteId);
      if (existing == null || existing.syncState == DocumentSyncState.synced) {
        if (existing != null) _documents.remove(existing.key.localId);
        _summaries.remove(remoteId);
        _deletedSummaryIds.remove(remoteId);
      }
    }
    _rebuildDefaultCatalogs();
    _notify();
  }

  @override
  Future<void> discardPendingAndImportRemote(RemoteDocument remote) async {
    final remoteId = remote.key.remoteId;
    if (remoteId == null) {
      throw ArgumentError('stale replacement requires a remote id');
    }
    final existing = _documentByRemoteId(remoteId);
    final stableKey = existing?.key ?? remote.key;
    if (existing != null) {
      _operations.removeWhere(
        (_, operation) => operation.documentKey.localId == existing.key.localId,
      );
    }
    _documents[stableKey.localId] = LocalDocument(
      key: stableKey,
      accountKey: accountKey,
      document: remote.document,
      localUpdatedAt: remote.document.updatedAt,
      serverRevision: remote.revision,
      baseServerRevision: remote.revision,
      serverHash: remote.serverHash,
      syncState: DocumentSyncState.synced,
      deletedLocally: remote.deleted,
    );
    _storeSummary(remote.document, deleted: remote.deleted);
    _notify();
  }

  @override
  Future<bool> discardStaleOperationAndImportRemote(
    String operationId,
    RemoteDocument remote,
  ) async {
    final operation = _operations.remove(operationId);
    if (operation == null) return false;
    final existing = _documents[operation.documentKey.localId];
    if (existing == null) return false;
    _documents[operation.documentKey.localId] = LocalDocument(
      key: DocumentKey(
        localId: operation.documentKey.localId,
        remoteId: remote.key.remoteId,
      ),
      accountKey: accountKey,
      document: remote.document,
      localUpdatedAt: remote.document.updatedAt,
      serverRevision: remote.revision,
      baseServerRevision: remote.revision,
      serverHash: remote.serverHash,
      syncState: DocumentSyncState.synced,
      deletedLocally: remote.deleted,
    );
    _storeSummary(remote.document, deleted: remote.deleted);
    _notify();
    return true;
  }

  @override
  Future<void> saveDraftAndEnqueue(
    LocalDocument document, {
    required PendingOperation operation,
  }) async {
    _validateWrite(document, operation);
    final existingOperation = _operationForDocument(document.key);
    final nextOperation = existingOperation == null
        ? operation
        : coalescer.coalesce(existingOperation, operation);

    final saved = document.copyWith(
      syncState: nextOperation == null
          ? DocumentSyncState.synced
          : DocumentSyncState.queued,
    );
    _documents[document.key.localId] = saved;
    if (saved.key.remoteId != null) {
      _storeSummary(saved.document, deleted: saved.deletedLocally);
    }
    _rebuildDefaultCatalogs();
    if (existingOperation != null) {
      _operations.remove(existingOperation.operationId);
    }
    if (nextOperation != null) {
      _operations[nextOperation.operationId] = nextOperation;
    }
    _notify();
  }

  @override
  Future<List<PendingOperation>> pendingOperations() async {
    final rows = _operations.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return rows;
  }

  @override
  Future<PendingOperation?> claimNextOperation({
    required String workerId,
    required Duration lease,
    required DateTime now,
  }) async {
    if (lease <= Duration.zero) {
      throw ArgumentError.value(lease, 'lease', 'must be positive');
    }
    final eligible =
        _operations.values
            .where((operation) => operation.isEligibleAt(now))
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    if (eligible.isEmpty) return null;
    final claimed = eligible.first.copyWith(
      status: PendingOperationStatus.claimed,
      leaseOwner: workerId,
      leaseExpiresAt: now.add(lease),
      clearNextAttemptAt: true,
    );
    _operations[claimed.operationId] = claimed;
    final local = _documents[claimed.documentKey.localId];
    if (local != null) {
      _documents[local.key.localId] = local.copyWith(
        syncState: DocumentSyncState.syncing,
      );
    }
    _notify();
    return claimed;
  }

  @override
  Future<void> completeOperation(
    String operationId, {
    required RemoteWriteResult result,
  }) async {
    final operation = _operations.remove(operationId);
    if (operation == null) return;
    final local = _documents[operation.documentKey.localId];
    if (local != null) {
      _documents[local.key.localId] = local.copyWith(
        key: result.key,
        serverRevision: result.revision,
        baseServerRevision: result.revision,
        serverHash: result.serverHash,
        syncState: DocumentSyncState.synced,
      );
    }
    _notify();
  }

  @override
  Future<void> completeCreateOperation(
    String operationId, {
    required RemoteDocument document,
  }) async {
    final operation = _operations.remove(operationId);
    if (operation == null) return;
    final existing = _documents.remove(operation.documentKey.localId);
    if (existing == null) return;
    final key = DocumentKey(
      localId: existing.key.localId,
      remoteId: document.key.remoteId,
    );
    _documents[key.localId] = LocalDocument(
      key: key,
      accountKey: accountKey,
      document: document.document,
      localUpdatedAt: document.document.updatedAt,
      serverRevision: document.revision,
      baseServerRevision: document.revision,
      serverHash: document.serverHash,
      syncState: DocumentSyncState.synced,
    );
    _storeSummary(document.document);
    _notify();
  }

  @override
  Future<void> failOperation(
    String operationId, {
    required SyncFailure failure,
    required DateTime retryAt,
  }) async {
    final operation = _operations[operationId];
    if (operation == null) return;
    _operations[operationId] = operation.copyWith(
      status: failure.isRetryable
          ? PendingOperationStatus.retryWaiting
          : PendingOperationStatus.blocked,
      attemptCount: operation.attemptCount + 1,
      nextAttemptAt: retryAt,
      clearLeaseOwner: true,
      clearLeaseExpiresAt: true,
      lastError: failure.message,
    );
    final local = _documents[operation.documentKey.localId];
    if (local != null) {
      _documents[local.key.localId] = local.copyWith(
        syncState: failure.kind == SyncFailureKind.conflict
            ? DocumentSyncState.conflict
            : DocumentSyncState.retryWaiting,
      );
    }
    _notify();
  }

  void _validateWrite(LocalDocument document, PendingOperation operation) {
    if (document.accountKey != accountKey ||
        operation.accountKey != accountKey) {
      throw StateError('write belongs to a different account');
    }
    if (document.key != operation.documentKey) {
      throw StateError('document and operation keys do not match');
    }
  }

  PendingOperation? _operationForDocument(DocumentKey key) {
    for (final operation in _operations.values) {
      if (operation.documentKey == key) return operation;
    }
    return null;
  }

  LocalDocument? _documentByRemoteId(int remoteId) {
    for (final document in _documents.values) {
      if (document.key.remoteId == remoteId) return document;
    }
    return null;
  }

  List<DocumentSummary> _visibleSummaries() {
    final rows = <DocumentSummary>[
      for (final entry in _summaries.entries)
        if (!_deletedSummaryIds.contains(entry.key)) entry.value,
    ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return rows;
  }

  List<DocumentSummary> _filterSummaries(
    List<DocumentSummary> rows,
    CatalogQuery query,
  ) {
    final search = query.searchText.trim().toLowerCase();
    return rows
        .where((summary) {
          if (search.isNotEmpty &&
              !<String>[
                summary.title,
                summary.excerpt,
                ...summary.tagsBySystem.values.expand((tags) => tags),
              ].join(' ').toLowerCase().contains(search)) {
            return false;
          }
          final tag = query.tagFilter;
          if (tag != null &&
              !(summary.tagsBySystem[tag.system]?.contains(tag.node) ??
                  false)) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
  }

  void _storeSummary(NxDocument document, {bool deleted = false}) {
    _summaries[document.id] = DocumentSummary.fromDocument(document);
    if (deleted) {
      _deletedSummaryIds.add(document.id);
    } else {
      _deletedSummaryIds.remove(document.id);
    }
    final pinnedCatalogs = <String>{
      const CatalogQuery.pinned().cacheKey,
      const CatalogQuery.pinned(limit: 50).cacheKey,
      ..._catalogs.keys.where((key) => key.startsWith('pinned:')),
    };
    for (final key in pinnedCatalogs) {
      final ids = _catalogs.putIfAbsent(key, () => <int>[]);
      ids.remove(document.id);
      if (document.pinned && !deleted) ids.insert(0, document.id);
    }
  }

  void _rebuildDefaultCatalogs() {
    final summaries = _visibleSummaries();
    _catalogs[const CatalogQuery.all().cacheKey] = <int>[
      for (final summary in summaries) summary.id,
    ];
    _catalogs[const CatalogQuery.recent().cacheKey] = <int>[
      for (final summary in summaries.take(20)) summary.id,
    ];
    _catalogs[const CatalogQuery.pinned().cacheKey] = <int>[
      for (final summary in summaries.where((item) => item.pinned).take(20))
        summary.id,
    ];
    _catalogs[const CatalogQuery.books().cacheKey] = <int>[
      for (final summary in summaries.where((item) => item.isBook)) summary.id,
    ];
  }

  void _notify() {
    if (!_disposed) _changes.add(null);
  }

  Stream<T> _watch<T>(T Function() read) {
    StreamSubscription<void>? subscription;
    late final StreamController<T> controller;
    controller = StreamController<T>(
      onListen: () {
        controller.add(read());
        subscription = _changes.stream.listen((_) => controller.add(read()));
      },
      onCancel: () => subscription?.cancel(),
    );
    return controller.stream;
  }
}
