import 'package:nx_notes/domain/sync/pending_operation.dart';

class OutboxCoalescer {
  const OutboxCoalescer();

  PendingOperation? coalesce(
    PendingOperation existing,
    PendingOperation incoming,
  ) {
    if (existing.accountKey != incoming.accountKey ||
        existing.documentKey != incoming.documentKey) {
      throw ArgumentError(
        'operations must target the same account and document',
      );
    }

    final nextType = switch ((existing.type, incoming.type)) {
      (PendingOperationType.create, PendingOperationType.update) =>
        PendingOperationType.create,
      (PendingOperationType.create, PendingOperationType.delete) => null,
      (PendingOperationType.update, PendingOperationType.update) =>
        PendingOperationType.update,
      (PendingOperationType.update, PendingOperationType.delete) =>
        PendingOperationType.delete,
      (PendingOperationType.delete, PendingOperationType.delete) =>
        PendingOperationType.delete,
      (PendingOperationType.create, PendingOperationType.create) =>
        throw StateError('a document cannot have two pending creates'),
      (PendingOperationType.update, PendingOperationType.create) =>
        throw StateError('create cannot follow update'),
      (PendingOperationType.delete, PendingOperationType.create) =>
        throw StateError('create cannot follow delete'),
      (PendingOperationType.delete, PendingOperationType.update) =>
        throw StateError('update cannot follow delete without restoration'),
    };

    if (nextType == null) return null;
    return incoming.copyWith(
      operationId: existing.operationId,
      type: nextType,
      baseRevision: existing.baseRevision,
      clearBaseRevision: existing.baseRevision == null,
      status: PendingOperationStatus.queued,
      attemptCount: 0,
      clearNextAttemptAt: true,
      clearLeaseOwner: true,
      clearLeaseExpiresAt: true,
      clearLastError: true,
      createdAt: existing.createdAt,
    );
  }
}
