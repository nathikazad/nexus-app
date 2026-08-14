import 'dart:async';

import '../core/sync_models.dart';
import 'sync_ports.dart';

typedef SyncPreparation = Future<void> Function();

/// Application-owned pull behavior used by [SyncSupervisor].
///
/// The application keeps ownership of its transport, merge rules, and local
/// projections. The supervisor owns when those operations are allowed to run.
abstract interface class PullReconciler<K> {
  Future<void> pullAll();

  Future<void> pullKeys(Set<K> keys);
}

/// Serializes and coalesces all pull synchronization for one account.
///
/// There is never more than one active pull. Full pulls subsume keyed pulls,
/// keyed requests are unioned into one batch, and equivalent requests share
/// the active run. Requests arriving during narrower work produce at most one
/// follow-up batch.
final class SyncSupervisor<K> implements SyncStatusSource {
  SyncSupervisor({
    required PullReconciler<K> reconciler,
    SyncPreparation? prepare,
    this.coalescingWindow = const Duration(milliseconds: 50),
  }) : _reconciler = reconciler,
       _prepare = prepare;

  final PullReconciler<K> _reconciler;
  final SyncPreparation? _prepare;
  final Duration coalescingWindow;
  final StreamController<SyncStatus> _statusController =
      StreamController<SyncStatus>.broadcast(sync: true);

  final Set<K> _pendingKeys = <K>{};
  final Set<SyncReason> _pendingReasons = <SyncReason>{};
  final List<Completer<void>> _pendingWaiters = <Completer<void>>[];
  bool _pendingFull = false;
  _SyncBatch<K>? _activeBatch;
  Future<void>? _activeRun;
  Timer? _coalescingTimer;
  SyncStatus _status = const SyncStatus.idle();
  bool _closed = false;

  @override
  SyncStatus get status => _status;

  @override
  Stream<SyncStatus> get statusChanges => _statusController.stream;

  Future<void> requestFull(SyncReason reason) {
    if (_closed) return Future<void>.error(StateError('SyncSupervisor closed'));
    final completer = Completer<void>();
    final active = _activeBatch;
    if (active != null && active.full) {
      active.reasons.add(reason);
      active.waiters.add(completer);
      return completer.future;
    }
    _pendingFull = true;
    _pendingKeys.clear();
    _pendingReasons.add(reason);
    _pendingWaiters.add(completer);
    _schedule();
    return completer.future;
  }

  Future<void> requestKey(K key, SyncReason reason) {
    return requestKeys(<K>{key}, reason);
  }

  Future<void> requestKeys(Iterable<K> keys, SyncReason reason) {
    if (_closed) return Future<void>.error(StateError('SyncSupervisor closed'));
    final requested = keys.toSet();
    if (requested.isEmpty) return Future<void>.value();

    final completer = Completer<void>();
    final active = _activeBatch;
    if (active != null) {
      if (active.full || active.keys.containsAll(requested)) {
        active.reasons.add(reason);
        active.waiters.add(completer);
        return completer.future;
      }
      requested.removeAll(active.keys);
    }

    if (!_pendingFull) _pendingKeys.addAll(requested);
    _pendingReasons.add(reason);
    _pendingWaiters.add(completer);
    _schedule();
    return completer.future;
  }

  void _schedule() {
    if (_closed || _activeRun != null || _coalescingTimer != null) return;
    if (coalescingWindow <= Duration.zero) {
      scheduleMicrotask(_start);
      return;
    }
    _coalescingTimer = Timer(coalescingWindow, _start);
  }

  void _start() {
    _coalescingTimer?.cancel();
    _coalescingTimer = null;
    if (_closed || _activeRun != null || !_hasPending) return;
    final run = _drain();
    _activeRun = run;
    unawaited(
      run.whenComplete(() {
        if (identical(_activeRun, run)) _activeRun = null;
        if (_hasPending) _schedule();
      }),
    );
  }

  bool get _hasPending =>
      _pendingFull || _pendingKeys.isNotEmpty || _pendingWaiters.isNotEmpty;

  _SyncBatch<K> _takePending() {
    final batch = _SyncBatch<K>(
      full: _pendingFull,
      keys: Set<K>.of(_pendingKeys),
      reasons: Set<SyncReason>.of(_pendingReasons),
      waiters: List<Completer<void>>.of(_pendingWaiters),
    );
    _pendingFull = false;
    _pendingKeys.clear();
    _pendingReasons.clear();
    _pendingWaiters.clear();
    return batch;
  }

  Future<void> _drain() async {
    while (!_closed && _hasPending) {
      final batch = _takePending();
      _activeBatch = batch;
      _setStatus(
        SyncStatus(
          activity: SyncActivity.syncing,
          pendingCount: batch.full ? 1 : batch.keys.length,
          message: _reasonMessage(batch.reasons),
        ),
      );
      try {
        await _prepare?.call();
        if (batch.full) {
          await _reconciler.pullAll();
        } else {
          await _reconciler.pullKeys(Set<K>.unmodifiable(batch.keys));
        }
        for (final waiter in batch.waiters) {
          if (!waiter.isCompleted) waiter.complete();
        }
        _setStatus(
          SyncStatus(
            activity: SyncActivity.idle,
            pendingCount: 0,
            lastSyncedAt: DateTime.now().toUtc(),
          ),
        );
      } catch (error, stackTrace) {
        for (final waiter in batch.waiters) {
          if (!waiter.isCompleted) waiter.completeError(error, stackTrace);
        }
        _failPending(error, stackTrace);
        _setStatus(
          SyncStatus(
            activity: SyncActivity.retryWaiting,
            pendingCount: 0,
            message: error.toString(),
          ),
        );
        break;
      } finally {
        if (identical(_activeBatch, batch)) _activeBatch = null;
      }
    }
  }

  void _failPending(Object error, StackTrace stackTrace) {
    for (final waiter in _pendingWaiters) {
      if (!waiter.isCompleted) waiter.completeError(error, stackTrace);
    }
    _pendingFull = false;
    _pendingKeys.clear();
    _pendingReasons.clear();
    _pendingWaiters.clear();
  }

  String? _reasonMessage(Set<SyncReason> reasons) {
    if (reasons.isEmpty) return null;
    return reasons.map((reason) => reason.name).join(', ');
  }

  void _setStatus(SyncStatus next) {
    _status = next;
    if (!_statusController.isClosed) _statusController.add(next);
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _coalescingTimer?.cancel();
    _coalescingTimer = null;
    final error = StateError('SyncSupervisor closed');
    _failPending(error, StackTrace.current);
    final active = _activeRun;
    if (active != null) {
      try {
        await active;
      } catch (_) {
        // Active callers receive the original synchronization error.
      }
    }
    await _statusController.close();
  }
}

final class _SyncBatch<K> {
  _SyncBatch({
    required this.full,
    required this.keys,
    required this.reasons,
    required this.waiters,
  });

  final bool full;
  final Set<K> keys;
  final Set<SyncReason> reasons;
  final List<Completer<void>> waiters;
}
