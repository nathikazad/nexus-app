import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_offline/nx_offline.dart';

void main() {
  test('a revision arriving during sync schedules a follow-up', () async {
    final first = Completer<void>();
    var calls = 0;
    final coordinator = AppStateCoordinator(
      synchronize: (_) async {
        calls++;
        if (calls == 1) await first.future;
      },
    );
    final running = coordinator.request(SyncReason.appStarted);
    await Future<void>.delayed(Duration.zero);
    coordinator.hint('revision:2');
    coordinator.hint('revision:2');
    first.complete();
    await running;
    expect(calls, 2);
    await coordinator.close();
  });

  test(
    'simultaneous startup and reconnect coalesce before work starts',
    () async {
      var calls = 0;
      final coordinator = AppStateCoordinator(
        synchronize: (_) async {
          calls++;
        },
      );
      final first = coordinator.request(SyncReason.appStarted);
      coordinator.request(SyncReason.connectivityRestored);
      await first;
      expect(calls, 1);
      await coordinator.close();
    },
  );

  test('failed initial load retries without a manual sync', () async {
    var calls = 0;
    final recovered = Completer<void>();
    final coordinator = AppStateCoordinator(
      retryDelay: const Duration(milliseconds: 1),
      synchronize: (_) async {
        calls++;
        if (calls == 1) throw StateError('offline');
        recovered.complete();
      },
    );
    await coordinator.request(SyncReason.appStarted);
    await recovered.future;
    expect(calls, 2);
    await coordinator.close();
  });

  test('disposing during a pull suppresses queued work', () async {
    final first = Completer<void>();
    var calls = 0;
    final coordinator = AppStateCoordinator(
      synchronize: (_) async {
        calls++;
        await first.future;
      },
    );
    final running = coordinator.request(SyncReason.appStarted);
    await Future<void>.delayed(Duration.zero);
    coordinator.hint('new');
    final closed = coordinator.close();
    first.complete();
    await running;
    await closed;
    expect(calls, 1);
  });
}
