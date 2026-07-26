import 'dart:async';

import 'package:nx_notes/application/ports/local_notes_store.dart';
import 'package:nx_notes/application/sync/outbox_coalescer.dart';
import 'package:nx_notes/domain/document/document_identity.dart';
import 'package:nx_notes/domain/document/document_query.dart';
import 'package:nx_notes/domain/sync/local_document.dart';
import 'package:nx_notes/domain/sync/pending_operation.dart';
import 'package:nx_notes/domain/sync/remote_document.dart';
import 'package:nx_notes/domain/sync/sync_failure.dart';
import 'package:nx_notes/domain/sync/sync_conflict.dart';
import 'package:nx_notes/domain/sync/sync_state.dart';

class MemoryLocalNotesStore implements LocalNotesStore {
  MemoryLocalNotesStore({
    required this.accountKey,
    this.coalescer = const OutboxCoalescer(),
  });

  @override
  final String accountKey;
  final OutboxCoalescer coalescer;
  final Map<String, LocalDocument> _documents = <String, LocalDocument>{};
  final Map<String, PendingOperation> _operations =
      <String, PendingOperation>{};
  final StreamController<void> _changes = StreamController<void>.broadcast();
  final Map<String, SyncConflict> _conflicts = <String, SyncConflict>{};
  String? _syncCursor;
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
  Stream<List<LocalDocument>> watchDocuments(DocumentQuery query) {
    return _watch(() => _matchingDocuments(query));
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
        syncState: DocumentSyncState.synced,
        deletedLocally: remote.deleted,
      );
      changed = true;
    }
    if (changed) _notify();
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

    _documents[document.key.localId] = document.copyWith(
      syncState: nextOperation == null
          ? DocumentSyncState.synced
          : DocumentSyncState.queued,
    );
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
    if (operation == null) {
      throw StateError('pending operation not found: $operationId');
    }
    final local = _documents[operation.documentKey.localId];
    if (local != null) {
      _documents[local.key.localId] = local.copyWith(
        key: result.key,
        serverRevision: result.revision,
        baseServerRevision: result.revision,
        syncState: DocumentSyncState.synced,
      );
    }
    _notify();
  }

  @override
  Future<void> failOperation(
    String operationId, {
    required SyncFailure failure,
    required DateTime retryAt,
  }) async {
    final operation = _operations[operationId];
    if (operation == null) {
      throw StateError('pending operation not found: $operationId');
    }
    _operations[operationId] = operation.copyWith(
      status: PendingOperationStatus.retryWaiting,
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

  @override
  Future<String?> readSyncCursor() async => _syncCursor;

  @override
  Future<void> writeSyncCursor(String cursor) async {
    _syncCursor = cursor;
  }

  @override
  Future<void> recordConflict(SyncConflict conflict) async {
    _conflicts[conflict.documentKey.localId] = conflict;
    final local = _documents[conflict.documentKey.localId];
    if (local != null) {
      _documents[local.key.localId] = local.copyWith(
        syncState: DocumentSyncState.conflict,
      );
    }
    _notify();
  }

  @override
  Future<List<SyncConflict>> conflicts() async {
    final rows = _conflicts.values.toList()
      ..sort((a, b) => a.detectedAt.compareTo(b.detectedAt));
    return rows;
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

  List<LocalDocument> _matchingDocuments(DocumentQuery query) {
    final search = query.searchText.trim().toLowerCase();
    final rows = _documents.values.where((local) {
      if (local.accountKey != accountKey || local.deletedLocally) return false;
      final document = local.document;
      if (query.pinnedOnly && !document.pinned) return false;
      if (search.isNotEmpty &&
          !<String>[
            document.title,
            document.document,
            document.excerpt,
          ].join(' ').toLowerCase().contains(search)) {
        return false;
      }
      for (final filter in query.tagFilters) {
        final tags = document.tagsBySystem[filter.system] ?? const <String>[];
        if (!tags.contains(filter.node)) return false;
      }
      return true;
    }).toList()..sort((a, b) => b.localUpdatedAt.compareTo(a.localUpdatedAt));
    return rows;
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
