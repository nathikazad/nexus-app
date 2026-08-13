/// Coordinates one full reconciliation with independently keyed targeted
/// reconciliations.
///
/// A full run waits for targeted work already in flight. Targeted work that
/// arrives during a full run waits for it and reads the resulting local state
/// instead of issuing a duplicate request. Different targeted keys may still
/// run concurrently when no full reconciliation is active.
final class ReconciliationCoordinator<K, V> {
  final Map<K, Future<V>> _itemRuns = <K, Future<V>>{};
  Future<void>? _fullRun;

  Future<void> runFull(Future<void> Function() reconcile) {
    final active = _fullRun;
    if (active != null) return active;
    final run = _runFull(reconcile, _itemRuns.values.toList(growable: false));
    _fullRun = run;
    return run.whenComplete(() {
      if (identical(_fullRun, run)) _fullRun = null;
    });
  }

  Future<V> runItem(
    K key, {
    required Future<V> Function() reconcile,
    required Future<V> Function() readAfterFull,
  }) {
    final active = _itemRuns[key];
    if (active != null) return active;
    final full = _fullRun;
    final run = full == null
        ? reconcile()
        : _afterFull(full, reconcile: reconcile, readAfterFull: readAfterFull);
    _itemRuns[key] = run;
    return run.whenComplete(() {
      if (identical(_itemRuns[key], run)) _itemRuns.remove(key);
    });
  }

  Future<void> _runFull(
    Future<void> Function() reconcile,
    List<Future<V>> activeItems,
  ) async {
    for (final item in activeItems) {
      try {
        await item;
      } catch (_) {
        // A full reconciliation is the recovery path for failed targeted work.
      }
    }
    await reconcile();
  }

  Future<V> _afterFull(
    Future<void> full, {
    required Future<V> Function() reconcile,
    required Future<V> Function() readAfterFull,
  }) async {
    try {
      await full;
      return readAfterFull();
    } catch (_) {
      // The targeted request can still succeed when a broader request failed.
      return reconcile();
    }
  }
}
