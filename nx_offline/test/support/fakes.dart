import 'package:nx_offline/nx_offline.dart';

final class FakeClock implements Clock {
  FakeClock(this.value);

  DateTime value;

  @override
  DateTime now() => value;
}

final class MemoryOutboxStore implements OutboxStore {
  MemoryOutboxStore(this.account);

  @override
  final AccountIdentity account;

  final List<PendingMutation> mutations = <PendingMutation>[];

  Future<void> enqueue(PendingMutation mutation) async {
    if (mutation.account != account) throw StateError('account mismatch');
    mutations.add(mutation);
  }

  @override
  Future<List<PendingMutation>> pendingMutations() async =>
      List<PendingMutation>.unmodifiable(mutations);

  @override
  Future<DateTime?> nextRetryAt() async {
    DateTime? earliest;
    for (final mutation in mutations) {
      final retryAt = mutation.nextAttemptAt;
      if (mutation.status != PendingMutationStatus.retryWaiting ||
          retryAt == null) {
        continue;
      }
      if (earliest == null || retryAt.isBefore(earliest)) earliest = retryAt;
    }
    return earliest;
  }

  @override
  Future<PendingMutation?> claimNext({
    required String workerId,
    required DateTime now,
    required Duration lease,
  }) async {
    for (var index = 0; index < mutations.length; index++) {
      final mutation = mutations[index];
      if (!mutation.isEligibleAt(now)) continue;
      final claimed = mutation.copyWith(
        status: PendingMutationStatus.claimed,
        leaseOwner: workerId,
        leaseExpiresAt: now.add(lease),
        clearNextAttemptAt: true,
      );
      mutations[index] = claimed;
      return claimed;
    }
    return null;
  }

  @override
  Future<void> complete(MutationReceipt receipt) async {
    mutations.removeWhere(
      (mutation) => mutation.operationId == receipt.operationId,
    );
  }

  @override
  Future<void> fail(
    String operationId, {
    required SyncFailure failure,
    required DateTime retryAt,
  }) async {
    final index = mutations.indexWhere(
      (mutation) => mutation.operationId == operationId,
    );
    if (index < 0) throw StateError('mutation not found');
    final mutation = mutations[index];
    mutations[index] = mutation.copyWith(
      status: failure.isRetryable
          ? PendingMutationStatus.retryWaiting
          : PendingMutationStatus.blocked,
      attemptCount: mutation.attemptCount + 1,
      nextAttemptAt: retryAt,
      lastError: failure.message,
      clearLease: true,
    );
  }
}
