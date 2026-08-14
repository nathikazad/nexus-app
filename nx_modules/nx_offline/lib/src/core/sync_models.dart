enum MutationType { create, update, delete, relation }

enum PendingMutationStatus { queued, claimed, retryWaiting, blocked }

enum SyncFailureKind {
  transient,
  authentication,
  conflict,
  validation,
  unknown,
}

enum SyncActivity { idle, syncing, retryWaiting, blocked }

/// Why synchronization was requested.
///
/// The lifecycle layer reports intent only. Applications decide whether a
/// reason should upload an outbox, reconcile a library, or do both.
enum SyncReason {
  manual,
  foregroundDemand,
  appStarted,
  appResumed,
  connectivityRestored,
  timer,
}

/// Stable identity for one application's data partition.
///
/// [serverId] identifies the logical server/database, not a network route.
/// LAN, WAN, and Tailscale presets that reach the same database therefore use
/// the same identity and local cache.
final class AccountIdentity {
  const AccountIdentity({
    required this.serverId,
    required this.userId,
    required this.application,
  }) : assert(serverId != ''),
       assert(userId != ''),
       assert(application != '');

  final String serverId;
  final String userId;
  final String application;

  String get key => '$application:$serverId:$userId';

  @override
  bool operator ==(Object other) =>
      other is AccountIdentity &&
      serverId == other.serverId &&
      userId == other.userId &&
      application == other.application;

  @override
  int get hashCode => Object.hash(serverId, userId, application);
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
  final AccountIdentity account;
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
    if (status == PendingMutationStatus.blocked) return false;
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
}

final class MutationReceipt {
  const MutationReceipt({
    required this.operationId,
    required this.entityKey,
    required this.revision,
    this.metadata = const <String, Object?>{},
  });

  final String operationId;
  final EntityKey entityKey;
  final Revision revision;
  final Map<String, Object?> metadata;
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
