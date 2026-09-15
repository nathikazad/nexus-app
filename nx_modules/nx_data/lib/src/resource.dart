import 'dart:async';

/// A session-only view cache. Refresh retains data, and invalidation during a
/// read prevents that read from being considered current.
final class DataResource<T> {
  DataResource(this.load);
  final Future<T> Function() load;
  T? value;
  Object? error;
  bool stale = true;
  Future<T>? _pending;
  int _generation = 0;

  void invalidate() {
    stale = true;
    _generation++;
  }

  Future<T> read({bool refresh = false}) {
    if (!refresh && !stale && value != null) return Future.value(value);
    return _pending ??= _read().whenComplete(() => _pending = null);
  }

  Future<T> _read() async {
    try {
      // An event arriving mid-request must not be acknowledged with an older
      // response. Coalesced callers wait for the same up-to-date result.
      while (true) {
        final generation = _generation;
        final result = await load();
        value = result;
        error = null;
        if (generation != _generation) continue;
        stale = false;
        return result;
      }
    } catch (failure) {
      error = failure;
      rethrow;
    }
  }
}

/// Repository-owned cache; dispose it with the authenticated account scope.
final class DataCache {
  DataCache({this.retainCompleted = true});
  final bool retainCompleted;
  final Map<String, DataResource<Object?>> _resources = {};

  Future<T> read<T>(String key, Future<T> Function() load) async {
    final resource = _resources.putIfAbsent(key, () => DataResource(load));
    return await resource.read(refresh: !retainCompleted) as T;
  }

  void invalidate([String? prefix]) =>
      invalidateWhere((key) => prefix == null || key.startsWith(prefix));

  void invalidateWhere(bool Function(String key) matches) {
    for (final entry in _resources.entries) {
      if (matches(entry.key)) entry.value.invalidate();
    }
  }
}
