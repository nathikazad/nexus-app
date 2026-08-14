import 'package:nx_docs/sync/sync_models.dart';

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
    // A claimed operation may already be in flight. Give the new edit its own
    // id so completion of the older request cannot delete the newer draft.
    final existingIsInFlight =
        existing.status == PendingOperationStatus.claimed;
    return incoming.copyWith(
      operationId: existingIsInFlight
          ? incoming.operationId
          : existing.operationId,
      type: nextType,
      baseRevision: existing.baseRevision,
      clearBaseRevision: existing.baseRevision == null,
      status: PendingOperationStatus.queued,
      attemptCount: 0,
      clearNextAttemptAt: true,
      clearLeaseOwner: true,
      clearLeaseExpiresAt: true,
      clearLastError: true,
      createdAt: existingIsInFlight ? incoming.createdAt : existing.createdAt,
    );
  }
}
