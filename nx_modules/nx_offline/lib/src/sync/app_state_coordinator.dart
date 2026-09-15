import 'dart:async';
import '../core/sync_models.dart';

/// Coalesces wakeups while retaining changes received after a pull starts.
/// Hints are requests to check current state, never trusted content/checkpoints.
final class AppStateCoordinator {
  AppStateCoordinator({
    required this.synchronize,
    this.retryDelay = const Duration(seconds: 5),
  });

  final Future<void> Function(SyncReason reason) synchronize;
  final Duration retryDelay;
  Future<void>? _running;
  Timer? _retry;
  var _generation = 0;
  var _completed = 0;
  var _failures = 0;
  var _closed = false;
  String? _lastHint;
  SyncReason _reason = SyncReason.appStarted;

  void hint(String value) {
    if (_closed || value == _lastHint) return;
    _lastHint = value;
    unawaited(request(SyncReason.timer));
  }

  Future<void> request(SyncReason reason) {
    if (_closed) return Future.value();
    _reason = reason;
    _generation++;
    _retry?.cancel();
    return _running ??= Future<void>.microtask(
      _drain,
    ).whenComplete(() => _running = null);
  }

  Future<void> _drain() async {
    while (!_closed && _completed < _generation) {
      final target = _generation;
      try {
        await synchronize(_reason);
        _completed = target;
        _failures = 0;
      } catch (_) {
        if (!_closed) {
          final delay = retryDelay * (1 << _failures.clamp(0, 5));
          _failures++;
          _retry = Timer(delay, () => unawaited(request(SyncReason.timer)));
        }
        return;
      }
    }
  }

  Future<void> close() async {
    _closed = true;
    _retry?.cancel();
    await _running;
  }
}
