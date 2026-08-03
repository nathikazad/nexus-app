import 'dart:async';

import '../sync/sync_ports.dart';

abstract interface class ScheduledWake {
  void cancel();
}

typedef WakeFactory =
    ScheduledWake Function(Duration delay, void Function() callback);

/// Owns the single timer used to wake an outbox at its next durable retry.
final class RetryScheduler {
  RetryScheduler({required this.clock, WakeFactory? wakeFactory})
    : _wakeFactory = wakeFactory ?? _timerWake;

  final Clock clock;
  final WakeFactory _wakeFactory;
  ScheduledWake? _wake;
  DateTime? _scheduledAt;

  DateTime? get scheduledAt => _scheduledAt;

  void arm(DateTime? when, void Function() callback) {
    cancel();
    if (when == null) return;
    final now = clock.now();
    final delay = when.isAfter(now) ? when.difference(now) : Duration.zero;
    _scheduledAt = when;
    _wake = _wakeFactory(delay, () {
      _wake = null;
      _scheduledAt = null;
      callback();
    });
  }

  void cancel() {
    _wake?.cancel();
    _wake = null;
    _scheduledAt = null;
  }

  static ScheduledWake _timerWake(Duration delay, void Function() callback) {
    return _TimerWake(Timer(delay, callback));
  }
}

final class _TimerWake implements ScheduledWake {
  const _TimerWake(this.timer);

  final Timer timer;

  @override
  void cancel() => timer.cancel();
}
