import 'package:nx_notes/domain/document/document_identity.dart';
import 'package:nx_notes/domain/sync/document_revision.dart';

enum PendingOperationType { create, update, delete }

enum PendingOperationStatus { queued, claimed, retryWaiting }

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
