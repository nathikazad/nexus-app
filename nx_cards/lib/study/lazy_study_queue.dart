import 'dart:async';

/// Session-local preparation cache. Failures are retryable; closing prevents
/// later results from being delivered into a finished or replacement session.
class LazyStudyQueue<T> {
  LazyStudyQueue(this.length, this.load);
  final int length;
  final Future<T> Function(int) load;
  final _pending = <int, Future<T>>{};
  bool _closed = false;

  Future<T> prepare(int index) {
    if (_closed) return Future.error(StateError('Study session closed'));
    if (index < 0 || index >= length) {
      return Future.error(RangeError.index(index, List.filled(length, null)));
    }
    return _pending.putIfAbsent(index, () {
      // Schedule loading after insertion so synchronous failures are evicted too.
      return Future<T>(() async {
        try {
          if (_closed) throw StateError('Study session closed');
          final result = await load(index);
          if (_closed) throw StateError('Study session closed');
          return result;
        } catch (_) {
          _pending.remove(index);
          rethrow;
        }
      });
    });
  }

  void close() {
    _closed = true;
    _pending.clear();
  }
}
