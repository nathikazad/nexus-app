/// Owns one completed or in-flight setup per Bluetooth connection generation.
/// Invalidated work must check [isCurrent] after awaits before installing state.
class BleSetupLifecycle {
  int _generation = 0;
  String? _ready;
  String? _pendingKey;
  Future<bool>? _pending;
  Future<void> _tail = Future.value();

  bool isReady(String key) => _ready == key;

  void invalidate() {
    _generation++;
    _ready = null;
    _pendingKey = null;
    _pending = null;
  }

  Future<bool> ensure(
    String key,
    Future<bool> Function(bool Function() isCurrent) setup,
  ) {
    if (_ready == key) return Future.value(true);
    if (_pendingKey == key && _pending != null) return _pending!;
    if (_ready != null || _pendingKey != null) invalidate();
    final generation = _generation;
    bool current() => generation == _generation;
    final result = _tail.then((_) async {
      if (!current()) return false;
      try {
        final success = await setup(current);
        if (!current()) return false;
        if (success) _ready = key;
        return success;
      } finally {
        if (current()) {
          _pending = null;
          _pendingKey = null;
        }
      }
    });
    _pendingKey = key;
    _pending = result;
    _tail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }
}
