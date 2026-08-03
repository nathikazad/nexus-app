import 'package:flutter_test/flutter_test.dart';
import 'package:nx_offline/nx_offline.dart';

import '../support/fakes.dart';

void main() {
  test('arms one wake at the requested UTC time', () {
    final clock = FakeClock(DateTime.utc(2026, 8, 3, 10));
    final wakes = _WakeFactory();
    final scheduler = RetryScheduler(clock: clock, wakeFactory: wakes.call);
    var calls = 0;

    scheduler.arm(clock.now().add(const Duration(seconds: 5)), () => calls++);

    expect(wakes.delay, const Duration(seconds: 5));
    expect(scheduler.scheduledAt, DateTime.utc(2026, 8, 3, 10, 0, 5));
    wakes.wake!.fire();
    expect(calls, 1);
    expect(scheduler.scheduledAt, isNull);
  });

  test('rearming cancels the previous wake', () {
    final clock = FakeClock(DateTime.utc(2026, 8, 3, 10));
    final wakes = <_WakeFactory>[];
    final scheduler = RetryScheduler(
      clock: clock,
      wakeFactory: (delay, callback) {
        final factory = _WakeFactory()..call(delay, callback);
        wakes.add(factory);
        return factory.wake!;
      },
    );

    scheduler.arm(clock.now().add(const Duration(seconds: 5)), () {});
    scheduler.arm(clock.now().add(const Duration(seconds: 10)), () {});

    expect(wakes.first.wake!.cancelled, isTrue);
    expect(wakes.last.wake!.cancelled, isFalse);
  });
}

final class _WakeFactory {
  Duration? delay;
  _FakeWake? wake;

  ScheduledWake call(Duration value, void Function() callback) {
    delay = value;
    return wake = _FakeWake(callback);
  }
}

final class _FakeWake implements ScheduledWake {
  _FakeWake(this.callback);

  final void Function() callback;
  bool cancelled = false;

  void fire() {
    if (!cancelled) callback();
  }

  @override
  void cancel() => cancelled = true;
}
