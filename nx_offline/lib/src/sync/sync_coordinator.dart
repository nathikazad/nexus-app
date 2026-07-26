import 'dart:async';

import '../core/sync_models.dart';
import 'policies.dart';
import 'sync_ports.dart';

enum SyncReason { manual, appStarted, connectivityRestored, timer }

final class SyncCoordinator {
  SyncCoordinator({
    required this.store,
    required this.transport,
    required Iterable<SyncCollectionAdapter> collections,
    Iterable<PushConflictResolver> pushConflictResolvers = const [],
    required this.clock,
    required this.idGenerator,
    this.retryPolicy = const RetryPolicy(),
    this.operationLease = const Duration(minutes: 1),
  }) : _collections = {
         for (final collection in collections)
           collection.collectionName: collection,
       },
       _pushConflictResolvers = {
         for (final resolver in pushConflictResolvers)
           resolver.collectionName: resolver,
       } {
    if (_collections.length != collections.length) {
      throw ArgumentError('collection names must be unique');
    }
    if (operationLease <= Duration.zero) {
      throw ArgumentError.value(
        operationLease,
        'operationLease',
        'must be positive',
      );
    }
  }

  final SyncStore store;
  final SyncTransport transport;
  final Clock clock;
  final IdGenerator idGenerator;
  final RetryPolicy retryPolicy;
  final Duration operationLease;
  final Map<String, SyncCollectionAdapter> _collections;
  final Map<String, PushConflictResolver> _pushConflictResolvers;

  final StreamController<SyncStatus> _statusController =
      StreamController<SyncStatus>.broadcast();
  Future<SyncRunResult>? _activeRun;
  SyncStatus _status = const SyncStatus.idle();

  SyncStatus get status => _status;

  Stream<SyncStatus> get statusChanges => _statusController.stream;

  Future<SyncRunResult> synchronize({SyncReason reason = SyncReason.manual}) {
    final active = _activeRun;
    if (active != null) return active;
    final run = _run(reason);
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

  Future<void> dispose() => _statusController.close();

  Future<SyncRunResult> _run(SyncReason reason) async {
    final workerId = 'sync-${idGenerator.nextId()}';
    var pushed = 0;
    var pulled = 0;
    var tombstones = 0;
    var conflicts = 0;
    var failures = 0;
    var authenticationBlocked = false;

    await _emit(SyncActivity.syncing);

    while (true) {
      final mutation = await store.claimNext(
        workerId: workerId,
        now: clock.now(),
        lease: operationLease,
      );
      if (mutation == null) break;

      try {
        final receipt = await transport.push(mutation);
        await store.complete(receipt);
        pushed++;
      } on SyncTransportException catch (error) {
        failures++;
        final failure = error.failure;
        if (failure.kind == SyncFailureKind.conflict) {
          final resolver = _pushConflictResolvers[mutation.collection];
          if (resolver != null) {
            try {
              await resolver.resolvePushConflict(
                mutation: mutation,
                failure: failure,
              );
              conflicts++;
            } catch (_) {
              // The original mutation still needs durable failure state. The
              // collection can retry conflict materialization independently.
            }
          }
        }
        await store.fail(
          mutation.operationId,
          failure: failure,
          retryAt: failure.isRetryable
              ? retryPolicy.retryAt(clock.now(), mutation.attemptCount + 1)
              : clock.now().add(const Duration(days: 36500)),
        );
        if (failure.kind == SyncFailureKind.authentication) {
          authenticationBlocked = true;
          break;
        }
      } catch (error) {
        failures++;
        final failure = SyncFailure(
          kind: SyncFailureKind.unknown,
          message: error.toString(),
        );
        await store.fail(
          mutation.operationId,
          failure: failure,
          retryAt: retryPolicy.retryAt(clock.now(), mutation.attemptCount + 1),
        );
      }
    }

    if (!authenticationBlocked) {
      for (final collection in _collections.values) {
        try {
          final cursor = await store.readCursor(collection.collectionName);
          final page = await transport.pull(
            account: store.account,
            collection: collection.collectionName,
            modelTypes: collection.modelTypes,
            cursor: cursor,
          );
          for (final record in page.records) {
            try {
              await collection.applyRemote(record);
              pulled++;
            } on CollectionConflictException catch (error) {
              await store.recordConflict(error.conflict);
              await collection.preserveConflict(record);
              conflicts++;
            }
          }
          for (final tombstone in page.tombstones) {
            await collection.applyTombstone(tombstone);
            tombstones++;
          }
          await store.writeCursor(collection.collectionName, page.nextCursor);
        } on SyncTransportException catch (error) {
          failures++;
          if (error.failure.kind == SyncFailureKind.authentication) {
            authenticationBlocked = true;
            break;
          }
        } catch (_) {
          failures++;
        }
      }
    }

    final pending = await store.pendingMutations();
    final activity = authenticationBlocked
        ? SyncActivity.blocked
        : pending.isNotEmpty || failures > 0
        ? SyncActivity.retryWaiting
        : SyncActivity.idle;
    _setStatus(
      SyncStatus(
        activity: activity,
        pendingCount: pending.length,
        lastSyncedAt: activity == SyncActivity.idle ? clock.now() : null,
        message: authenticationBlocked
            ? 'Authentication is required before synchronization can continue.'
            : failures > 0
            ? 'Some changes could not be synchronized.'
            : conflicts > 0
            ? 'Some records need conflict resolution.'
            : null,
      ),
    );
    return SyncRunResult(
      pushedCount: pushed,
      pulledCount: pulled,
      tombstoneCount: tombstones,
      conflictCount: conflicts,
      failureCount: failures,
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
}
