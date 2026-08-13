import '../core/sync_models.dart';

/// Durable queue operations required by the shared upload runtime.
///
/// The application implements this interface over the same database that owns
/// its typed domain projection. Enqueuing a domain change remains an
/// application repository responsibility so both writes can share one
/// transaction.
abstract interface class OutboxStore {
  AccountIdentity get account;

  Future<List<PendingMutation>> pendingMutations();

  Future<PendingMutation?> claimNext({
    required String workerId,
    required DateTime now,
    required Duration lease,
  });

  Future<void> complete(MutationReceipt receipt);

  Future<void> fail(
    String operationId, {
    required SyncFailure failure,
    required DateTime retryAt,
  });

  /// Earliest persisted retry time, or null when no retry is waiting.
  Future<DateTime?> nextRetryAt();
}

abstract interface class Clock {
  DateTime now();
}

abstract interface class SyncStatusSource {
  SyncStatus get status;

  Stream<SyncStatus> get statusChanges;
}

final class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now().toUtc();
}
