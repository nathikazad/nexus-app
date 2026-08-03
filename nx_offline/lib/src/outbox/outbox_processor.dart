import 'dart:async';

import '../core/sync_models.dart';
import '../sync/policies.dart';
import '../sync/sync_ports.dart';
import 'retry_scheduler.dart';

/// Application-owned remote mutation behavior for one outbox collection.
abstract interface class MutationHandler {
  String get collection;

  Future<MutationReceipt> execute(PendingMutation mutation);
}

final class OutboxRunResult {
  const OutboxRunResult({
    required this.completedCount,
    required this.failureCount,
    required this.authenticationBlocked,
  });

  final int completedCount;
  final int failureCount;
  final bool authenticationBlocked;

  bool get succeeded => failureCount == 0 && !authenticationBlocked;
}

/// Shared durable delivery loop.
///
/// Applications own typed local writes and mutation semantics. This processor
/// owns claiming, handler routing, retry classification, single-flight
/// execution, retry wake-ups, and observable status.
final class OutboxProcessor implements SyncStatusSource {
  OutboxProcessor({
    required this.store,
    required Iterable<MutationHandler> handlers,
    required this.clock,
    required this.workerId,
    required this.scheduler,
    this.retryPolicy = const RetryPolicy(),
    this.operationLease = const Duration(minutes: 1),
  }) : _handlers = <String, MutationHandler>{
         for (final handler in handlers) handler.collection: handler,
       } {
    if (_handlers.length != handlers.length) {
      throw ArgumentError('mutation handler collections must be unique');
    }
    if (operationLease <= Duration.zero) {
      throw ArgumentError.value(
        operationLease,
        'operationLease',
        'must be positive',
      );
    }
  }

  final OutboxStore store;
  final Clock clock;
  final String workerId;
  final RetryScheduler scheduler;
  final RetryPolicy retryPolicy;
  final Duration operationLease;
  final Map<String, MutationHandler> _handlers;
  final StreamController<SyncStatus> _statusController =
      StreamController<SyncStatus>.broadcast(sync: true);

  Future<OutboxRunResult>? _activeRun;
  SyncStatus _status = const SyncStatus.idle();
  bool _closed = false;

  @override
  SyncStatus get status => _status;

  @override
  Stream<SyncStatus> get statusChanges => _statusController.stream;

  /// Requests processing after [delay], replacing any existing scheduled wake.
  void schedule({Duration delay = Duration.zero}) {
    if (_closed) return;
    scheduler.arm(clock.now().add(delay), () => unawaited(process()));
  }

  Future<OutboxRunResult> process() {
    if (_closed) {
      return Future<OutboxRunResult>.value(
        const OutboxRunResult(
          completedCount: 0,
          failureCount: 0,
          authenticationBlocked: false,
        ),
      );
    }
    scheduler.cancel();
    final active = _activeRun;
    if (active != null) return active;
    final run = _drain();
    _activeRun = run;
    unawaited(
      run.then<void>(
        (_) {
          if (identical(_activeRun, run)) _activeRun = null;
        },
        onError: (Object _, StackTrace _) {
          if (identical(_activeRun, run)) _activeRun = null;
        },
      ),
    );
    return run;
  }

  Future<OutboxRunResult> _drain() async {
    var completed = 0;
    var failures = 0;
    var authenticationBlocked = false;
    var hasBlockedOperation = false;
    await _emit(SyncActivity.syncing);

    while (!_closed) {
      final mutation = await store.claimNext(
        workerId: workerId,
        now: clock.now(),
        lease: operationLease,
      );
      if (mutation == null) break;
      final handler = _handlers[mutation.collection];
      if (handler == null) {
        failures++;
        hasBlockedOperation = true;
        await store.fail(
          mutation.operationId,
          failure: SyncFailure(
            kind: SyncFailureKind.validation,
            message: 'No mutation handler for ${mutation.collection}',
          ),
          retryAt: clock.now(),
        );
        continue;
      }

      try {
        final receipt = await handler.execute(mutation);
        if (receipt.operationId != mutation.operationId) {
          throw SyncTransportException(
            const SyncFailure(
              kind: SyncFailureKind.validation,
              message: 'Mutation receipt operation ID does not match',
            ),
          );
        }
        await store.complete(receipt);
        completed++;
      } on SyncTransportException catch (error) {
        failures++;
        final failure = error.failure;
        final retryAt = failure.isRetryable
            ? retryPolicy.retryAt(clock.now(), mutation.attemptCount + 1)
            : clock.now();
        await store.fail(
          mutation.operationId,
          failure: failure,
          retryAt: retryAt,
        );
        if (!failure.isRetryable) hasBlockedOperation = true;
        if (failure.kind == SyncFailureKind.authentication) {
          authenticationBlocked = true;
          break;
        }
        if (failure.isRetryable) break;
      } catch (error) {
        failures++;
        await store.fail(
          mutation.operationId,
          failure: SyncFailure(
            kind: SyncFailureKind.unknown,
            message: error.toString(),
          ),
          retryAt: retryPolicy.retryAt(clock.now(), mutation.attemptCount + 1),
        );
        break;
      }
    }

    final pending = await store.pendingMutations();
    final retryAt = await store.nextRetryAt();
    if (!_closed) {
      scheduler.arm(retryAt, () => unawaited(process()));
    }
    final activity = authenticationBlocked || hasBlockedOperation
        ? SyncActivity.blocked
        : pending.isNotEmpty
        ? SyncActivity.retryWaiting
        : SyncActivity.idle;
    _setStatus(
      SyncStatus(
        activity: activity,
        pendingCount: pending.length,
        lastSyncedAt: activity == SyncActivity.idle ? clock.now() : null,
        message: authenticationBlocked
            ? 'Authentication is required before synchronization can continue.'
            : hasBlockedOperation
            ? 'A local change requires attention.'
            : failures > 0
            ? 'Some changes are waiting to retry.'
            : null,
      ),
    );
    return OutboxRunResult(
      completedCount: completed,
      failureCount: failures,
      authenticationBlocked: authenticationBlocked,
    );
  }

  Future<void> _emit(SyncActivity activity) async {
    final pending = await store.pendingMutations();
    _setStatus(SyncStatus(activity: activity, pendingCount: pending.length));
  }

  void _setStatus(SyncStatus status) {
    _status = status;
    if (!_statusController.isClosed) _statusController.add(status);
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    scheduler.cancel();
    final active = _activeRun;
    if (active != null) {
      try {
        await active;
      } catch (_) {
        // Closing releases resources even if an adapter failed unexpectedly.
      }
    }
    await _statusController.close();
  }
}
