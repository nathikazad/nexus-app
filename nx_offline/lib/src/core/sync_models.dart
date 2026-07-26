import 'dart:convert';

enum MutationType { create, update, delete, relation }

enum PendingMutationStatus { queued, claimed, retryWaiting }

enum SyncFailureKind {
  transient,
  authentication,
  conflict,
  validation,
  unknown,
}

enum SyncActivity { idle, syncing, retryWaiting, blocked }

final class AccountScope {
  const AccountScope({
    required this.backend,
    required this.userId,
    required this.application,
  }) : assert(backend != ''),
       assert(userId != ''),
       assert(application != '');

  final String backend;
  final String userId;
  final String application;

  String get key => '$application:$backend:$userId';

  @override
  bool operator ==(Object other) =>
      other is AccountScope &&
      backend == other.backend &&
      userId == other.userId &&
      application == other.application;

  @override
  int get hashCode => Object.hash(backend, userId, application);
}

final class EntityKey {
  const EntityKey({required this.localId, this.remoteId})
    : assert(localId != ''),
      assert(remoteId == null || remoteId > 0);

  final String localId;
  final int? remoteId;

  EntityKey withRemoteId(int id) => EntityKey(localId: localId, remoteId: id);

  @override
  bool operator ==(Object other) =>
      other is EntityKey &&
      localId == other.localId &&
      remoteId == other.remoteId;

  @override
  int get hashCode => Object.hash(localId, remoteId);
}

extension type const Revision(String value) {
  factory Revision.checked(String value) {
    if (value.isEmpty) throw ArgumentError.value(value, 'value');
    return Revision(value);
  }
}

extension type const SyncCursor(String value) {
  factory SyncCursor.checked(String value) {
    if (value.isEmpty) throw ArgumentError.value(value, 'value');
    return SyncCursor(value);
  }
}

enum EntitySyncState { synced, queued, syncing, retryWaiting, conflict }

final class LocalEntity {
  const LocalEntity({
    required this.account,
    required this.collection,
    required this.key,
    required this.payload,
    required this.updatedAt,
    required this.syncState,
    this.revision,
    this.baseRevision,
    this.deleted = false,
  });

  final AccountScope account;
  final String collection;
  final EntityKey key;
  final Map<String, Object?> payload;
  final DateTime updatedAt;
  final EntitySyncState syncState;
  final Revision? revision;
  final Revision? baseRevision;
  final bool deleted;

  LocalEntity copyWith({
    EntityKey? key,
    Map<String, Object?>? payload,
    DateTime? updatedAt,
    EntitySyncState? syncState,
    Revision? revision,
    Revision? baseRevision,
    bool? deleted,
  }) {
    return LocalEntity(
      account: account,
      collection: collection,
      key: key ?? this.key,
      payload: payload ?? this.payload,
      updatedAt: updatedAt ?? this.updatedAt,
      syncState: syncState ?? this.syncState,
      revision: revision ?? this.revision,
      baseRevision: baseRevision ?? this.baseRevision,
      deleted: deleted ?? this.deleted,
    );
  }
}

final class SyncFailure {
  const SyncFailure({required this.kind, required this.message});

  final SyncFailureKind kind;
  final String message;

  bool get isRetryable =>
      kind == SyncFailureKind.transient || kind == SyncFailureKind.unknown;
}

final class SyncTransportException implements Exception {
  const SyncTransportException(this.failure);

  final SyncFailure failure;

  @override
  String toString() => 'SyncTransportException(${failure.message})';
}

final class PendingMutation {
  const PendingMutation({
    required this.operationId,
    required this.account,
    required this.collection,
    required this.entityKey,
    required this.type,
    required this.payload,
    required this.createdAt,
    this.baseRevision,
    this.status = PendingMutationStatus.queued,
    this.attemptCount = 0,
    this.nextAttemptAt,
    this.leaseOwner,
    this.leaseExpiresAt,
    this.lastError,
    this.operationGroup,
  });

  final String operationId;
  final AccountScope account;
  final String collection;
  final EntityKey entityKey;
  final MutationType type;
  final Map<String, Object?> payload;
  final Revision? baseRevision;
  final DateTime createdAt;
  final PendingMutationStatus status;
  final int attemptCount;
  final DateTime? nextAttemptAt;
  final String? leaseOwner;
  final DateTime? leaseExpiresAt;
  final String? lastError;
  final String? operationGroup;

  bool isEligibleAt(DateTime now) {
    if (status == PendingMutationStatus.claimed) {
      return leaseExpiresAt != null && !leaseExpiresAt!.isAfter(now);
    }
    return nextAttemptAt == null || !nextAttemptAt!.isAfter(now);
  }

  PendingMutation copyWith({
    EntityKey? entityKey,
    MutationType? type,
    Map<String, Object?>? payload,
    Revision? baseRevision,
    PendingMutationStatus? status,
    int? attemptCount,
    DateTime? nextAttemptAt,
    String? leaseOwner,
    DateTime? leaseExpiresAt,
    String? lastError,
    bool clearNextAttemptAt = false,
    bool clearLease = false,
  }) {
    return PendingMutation(
      operationId: operationId,
      account: account,
      collection: collection,
      entityKey: entityKey ?? this.entityKey,
      type: type ?? this.type,
      payload: payload ?? this.payload,
      baseRevision: baseRevision ?? this.baseRevision,
      createdAt: createdAt,
      status: status ?? this.status,
      attemptCount: attemptCount ?? this.attemptCount,
      nextAttemptAt: clearNextAttemptAt
          ? null
          : nextAttemptAt ?? this.nextAttemptAt,
      leaseOwner: clearLease ? null : leaseOwner ?? this.leaseOwner,
      leaseExpiresAt: clearLease ? null : leaseExpiresAt ?? this.leaseExpiresAt,
      lastError: lastError ?? this.lastError,
      operationGroup: operationGroup,
    );
  }

  String payloadJson() => jsonEncode(payload);
}

final class MutationReceipt {
  const MutationReceipt({
    required this.operationId,
    required this.entityKey,
    required this.revision,
  });

  final String operationId;
  final EntityKey entityKey;
  final Revision revision;
}

final class RemoteRecord {
  const RemoteRecord({
    required this.collection,
    required this.modelType,
    required this.entityKey,
    required this.revision,
    required this.payload,
  });

  final String collection;
  final String modelType;
  final EntityKey entityKey;
  final Revision revision;
  final Map<String, Object?> payload;
}

final class RemoteTombstone {
  const RemoteTombstone({
    required this.collection,
    required this.modelType,
    required this.entityKey,
    required this.revision,
  });

  final String collection;
  final String modelType;
  final EntityKey entityKey;
  final Revision revision;
}

final class RemoteChangePage {
  const RemoteChangePage({
    required this.records,
    required this.tombstones,
    required this.nextCursor,
  });

  final List<RemoteRecord> records;
  final List<RemoteTombstone> tombstones;
  final SyncCursor nextCursor;
}

final class SyncConflict {
  const SyncConflict({
    required this.account,
    required this.collection,
    required this.entityKey,
    required this.localPayload,
    required this.remotePayload,
    required this.remoteRevision,
    required this.detectedAt,
  });

  final AccountScope account;
  final String collection;
  final EntityKey entityKey;
  final Map<String, Object?> localPayload;
  final Map<String, Object?> remotePayload;
  final Revision remoteRevision;
  final DateTime detectedAt;
}

final class SyncStatus {
  const SyncStatus({
    required this.activity,
    required this.pendingCount,
    this.lastSyncedAt,
    this.message,
  });

  const SyncStatus.idle()
    : activity = SyncActivity.idle,
      pendingCount = 0,
      lastSyncedAt = null,
      message = null;

  final SyncActivity activity;
  final int pendingCount;
  final DateTime? lastSyncedAt;
  final String? message;
}

final class SyncRunResult {
  const SyncRunResult({
    required this.pushedCount,
    required this.pulledCount,
    required this.tombstoneCount,
    required this.failureCount,
  });

  final int pushedCount;
  final int pulledCount;
  final int tombstoneCount;
  final int failureCount;

  bool get succeeded => failureCount == 0;
}
