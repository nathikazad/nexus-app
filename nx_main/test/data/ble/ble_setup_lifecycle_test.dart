import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_voice_assistant/data/ble/ble_setup_lifecycle.dart';

void main() {
  test('overlapping and repeated setup installs only one listener', () async {
    final owner = BleSetupLifecycle();
    final gate = Completer<void>();
    final stream = StreamController<int>.broadcast(sync: true);
    final subscriptions = <StreamSubscription<int>>[];
    final received = <int>[];
    var calls = 0;
    Future<bool> setup(bool Function() current) async {
      calls++;
      await gate.future;
      if (!current()) return false;
      subscriptions.add(stream.stream.listen(received.add));
      return true;
    }

    final first = owner.ensure('necklace', setup);
    final second = owner.ensure('necklace', setup);
    expect(identical(first, second), isTrue);
    gate.complete();
    expect(await first, isTrue);
    expect(await owner.ensure('necklace', setup), isTrue);
    stream.add(42);
    expect(calls, 1);
    expect(received, [42]);
    for (final s in subscriptions) {
      await s.cancel();
    }
    await stream.close();
  });

  test(
      'disconnect during setup prevents stale installation and allows reconnect',
      () async {
    final owner = BleSetupLifecycle();
    final entered = Completer<void>();
    final release = Completer<void>();
    var installed = 0;
    final old = owner.ensure('necklace', (current) async {
      entered.complete();
      await release.future;
      if (!current()) return false;
      installed++;
      return true;
    });
    await entered.future;
    owner.invalidate();
    final next = owner.ensure('necklace', (current) async {
      expect(current(), isTrue);
      installed++;
      return true;
    });
    release.complete();
    expect(await old, isFalse);
    expect(await next, isTrue);
    expect(installed, 1);
    expect(owner.isReady('necklace'), isTrue);
  });

  test('failure is retryable and device replacement invalidates old setup',
      () async {
    final owner = BleSetupLifecycle();
    await expectLater(
        owner.ensure('a', (_) async => throw StateError('failed')),
        throwsStateError);
    expect(await owner.ensure('a', (_) async => false), isFalse);
    expect(await owner.ensure('a', (_) async => true), isTrue);
    expect(await owner.ensure('b', (_) async => true), isTrue);
    expect(owner.isReady('a'), isFalse);
    owner.invalidate();
    expect(owner.isReady('b'), isFalse);
    expect(await owner.ensure('b', (_) async => true), isTrue);
  });
}
