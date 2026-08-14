import 'package:nx_docs/documents/document_models.dart';

class RemoteRevision {
  const RemoteRevision(this.value) : assert(value != '');

  final String value;

  @override
  bool operator ==(Object other) {
    return other is RemoteRevision && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

final class DocumentManifestEntry {
  const DocumentManifestEntry({required this.documentId, this.serverHash});

  final int documentId;
  final String? serverHash;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': documentId,
    'hash': serverHash,
  };
}

final class DocumentSyncBundle {
  const DocumentSyncBundle({
    this.documents = const <RemoteDocument>[],
    this.deletedIds = const <int>[],
  });

  final List<RemoteDocument> documents;
  final List<int> deletedIds;
}

class LocalDocument {
  const LocalDocument({
    required this.key,
    required this.accountKey,
    required this.document,
    required this.localUpdatedAt,
    required this.syncState,
    this.serverRevision,
    this.baseServerRevision,
    this.serverHash,
    this.deletedLocally = false,
  });

  final DocumentKey key;
  final String accountKey;
  final NxDocument document;
  final DateTime localUpdatedAt;
  final RemoteRevision? serverRevision;
  final RemoteRevision? baseServerRevision;
  final String? serverHash;
  final DocumentSyncState syncState;
  final bool deletedLocally;

  LocalDocument copyWith({
    DocumentKey? key,
    String? accountKey,
    NxDocument? document,
    DateTime? localUpdatedAt,
    RemoteRevision? serverRevision,
    bool clearServerRevision = false,
    RemoteRevision? baseServerRevision,
    bool clearBaseServerRevision = false,
    String? serverHash,
    bool clearServerHash = false,
    DocumentSyncState? syncState,
    bool? deletedLocally,
  }) {
    return LocalDocument(
      key: key ?? this.key,
      accountKey: accountKey ?? this.accountKey,
      document: document ?? this.document,
      localUpdatedAt: localUpdatedAt ?? this.localUpdatedAt,
      serverRevision: clearServerRevision
          ? null
          : serverRevision ?? this.serverRevision,
      baseServerRevision: clearBaseServerRevision
          ? null
          : baseServerRevision ?? this.baseServerRevision,
      serverHash: clearServerHash ? null : serverHash ?? this.serverHash,
      syncState: syncState ?? this.syncState,
      deletedLocally: deletedLocally ?? this.deletedLocally,
    );
  }
}

class LocalSnapshot {
  const LocalSnapshot({
    required this.snapshotId,
    required this.accountKey,
    required this.documentKey,
    required this.document,
    required this.createdAt,
    required this.source,
  });

  final String snapshotId;
  final String accountKey;
  final DocumentKey documentKey;
  final NxDocument document;
  final DateTime createdAt;
  final String source;
}

enum PendingOperationType { create, update, delete }

enum PendingOperationStatus { queued, claimed, retryWaiting, blocked }

class PendingOperation {
  const PendingOperation({
    required this.operationId,
    required this.accountKey,
    required this.documentKey,
    required this.type,
    required this.payload,
    required this.createdAt,
    this.baseRevision,
    this.status = PendingOperationStatus.queued,
    this.attemptCount = 0,
    this.nextAttemptAt,
    this.leaseOwner,
    this.leaseExpiresAt,
    this.lastError,
  });

  final String operationId;
  final String accountKey;
  final DocumentKey documentKey;
  final PendingOperationType type;
  final Map<String, Object?> payload;
  final RemoteRevision? baseRevision;
  final PendingOperationStatus status;
  final int attemptCount;
  final DateTime? nextAttemptAt;
  final String? leaseOwner;
  final DateTime? leaseExpiresAt;
  final String? lastError;
  final DateTime createdAt;

  bool isEligibleAt(DateTime now) {
    if (status == PendingOperationStatus.blocked) return false;
    if (status == PendingOperationStatus.claimed) {
      return leaseExpiresAt != null && !leaseExpiresAt!.isAfter(now);
    }
    return nextAttemptAt == null || !nextAttemptAt!.isAfter(now);
  }

  PendingOperation copyWith({
    String? operationId,
    String? accountKey,
    DocumentKey? documentKey,
    PendingOperationType? type,
    Map<String, Object?>? payload,
    RemoteRevision? baseRevision,
    bool clearBaseRevision = false,
    PendingOperationStatus? status,
    int? attemptCount,
    DateTime? nextAttemptAt,
    bool clearNextAttemptAt = false,
    String? leaseOwner,
    bool clearLeaseOwner = false,
    DateTime? leaseExpiresAt,
    bool clearLeaseExpiresAt = false,
    String? lastError,
    bool clearLastError = false,
    DateTime? createdAt,
  }) {
    return PendingOperation(
      operationId: operationId ?? this.operationId,
      accountKey: accountKey ?? this.accountKey,
      documentKey: documentKey ?? this.documentKey,
      type: type ?? this.type,
      payload: payload ?? this.payload,
      baseRevision: clearBaseRevision
          ? null
          : baseRevision ?? this.baseRevision,
      status: status ?? this.status,
      attemptCount: attemptCount ?? this.attemptCount,
      nextAttemptAt: clearNextAttemptAt
          ? null
          : nextAttemptAt ?? this.nextAttemptAt,
      leaseOwner: clearLeaseOwner ? null : leaseOwner ?? this.leaseOwner,
      leaseExpiresAt: clearLeaseExpiresAt
          ? null
          : leaseExpiresAt ?? this.leaseExpiresAt,
      lastError: clearLastError ? null : lastError ?? this.lastError,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class RemoteDocument {
  const RemoteDocument({
    required this.key,
    required this.document,
    required this.revision,
    this.serverHash,
    this.deleted = false,
  });

  final DocumentKey key;
  final NxDocument document;
  final RemoteRevision revision;
  final String? serverHash;
  final bool deleted;
}

class RemoteWriteResult {
  const RemoteWriteResult({
    required this.key,
    required this.revision,
    this.serverHash,
  });

  final DocumentKey key;
  final RemoteRevision revision;
  final String? serverHash;
}

enum RemoteSaveStatus { applied, stale }

final class RemoteSaveResult {
  const RemoteSaveResult({
    required this.status,
    required this.documentId,
    required this.updatedAt,
    this.serverHash,
  });

  final RemoteSaveStatus status;
  final int documentId;
  final DateTime updatedAt;
  final String? serverHash;
}

class SyncConflict {
  const SyncConflict({
    required this.documentKey,
    required this.localDocument,
    required this.remoteDocument,
    required this.remoteRevision,
    required this.detectedAt,
  });

  final DocumentKey documentKey;
  final NxDocument localDocument;
  final NxDocument remoteDocument;
  final RemoteRevision remoteRevision;
  final DateTime detectedAt;
}

enum SyncFailureKind {
  transient,
  authentication,
  validation,
  conflict,
  cancelled,
  unknown,
}

class SyncFailure {
  const SyncFailure({required this.kind, required this.message});

  final SyncFailureKind kind;
  final String message;

  bool get isRetryable =>
      kind == SyncFailureKind.transient || kind == SyncFailureKind.unknown;
}

enum DocumentSyncState {
  synced,
  locallyModified,
  queued,
  syncing,
  retryWaiting,
  conflict,
}

extension DocumentSyncStateTransitions on DocumentSyncState {
  bool canTransitionTo(DocumentSyncState next) {
    if (next == this) return true;
    return switch (this) {
      DocumentSyncState.synced =>
        next == DocumentSyncState.locallyModified ||
            next == DocumentSyncState.queued,
      DocumentSyncState.locallyModified =>
        next == DocumentSyncState.queued || next == DocumentSyncState.conflict,
      DocumentSyncState.queued =>
        next == DocumentSyncState.syncing ||
            next == DocumentSyncState.locallyModified ||
            next == DocumentSyncState.conflict,
      DocumentSyncState.syncing =>
        next == DocumentSyncState.synced ||
            next == DocumentSyncState.retryWaiting ||
            next == DocumentSyncState.conflict ||
            next == DocumentSyncState.locallyModified,
      DocumentSyncState.retryWaiting =>
        next == DocumentSyncState.syncing ||
            next == DocumentSyncState.locallyModified ||
            next == DocumentSyncState.conflict,
      DocumentSyncState.conflict =>
        next == DocumentSyncState.locallyModified ||
            next == DocumentSyncState.synced,
    };
  }
}

enum SyncActivity { idle, offline, syncing, retryWaiting, blocked }

class SyncStatus {
  const SyncStatus({
    required this.activity,
    this.pendingCount = 0,
    this.lastSyncedAt,
    this.message,
  });

  const SyncStatus.idle({DateTime? lastSyncedAt})
    : this(activity: SyncActivity.idle, lastSyncedAt: lastSyncedAt);

  final SyncActivity activity;
  final int pendingCount;
  final DateTime? lastSyncedAt;
  final String? message;
}
