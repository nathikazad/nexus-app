import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nx_offline/nx_offline.dart';

void main() {
  test('concurrent full requests share one reconciliation', () async {
    final coordinator = ReconciliationCoordinator<int, String>();
    final barrier = Completer<void>();
    var calls = 0;

    final first = coordinator.runFull(() async {
      calls++;
      await barrier.future;
    });
    final second = coordinator.runFull(() async => calls++);

    expect(calls, 1);
    barrier.complete();
    await Future.wait([first, second]);
    expect(calls, 1);
  });

  test(
    'targeted request during full run reads reconciled local state',
    () async {
      final coordinator = ReconciliationCoordinator<int, String>();
      final barrier = Completer<void>();
      var targetedCalls = 0;
      var local = 'cached';

      final full = coordinator.runFull(() async {
        await barrier.future;
        local = 'from full';
      });
      final item = coordinator.runItem(
        7,
        reconcile: () async {
          targetedCalls++;
          return 'targeted';
        },
        readAfterFull: () async => local,
      );

      expect(targetedCalls, 0);
      barrier.complete();
      await full;
      expect(await item, 'from full');
      expect(targetedCalls, 0);
    },
  );

  test('full run waits for targeted work already in flight', () async {
    final coordinator = ReconciliationCoordinator<int, String>();
    final barrier = Completer<void>();
    var fullStarted = false;

    final item = coordinator.runItem(
      7,
      reconcile: () async {
        await barrier.future;
        return 'targeted';
      },
      readAfterFull: () async => 'local',
    );
    final full = coordinator.runFull(() async => fullStarted = true);

    await Future<void>.delayed(Duration.zero);
    expect(fullStarted, isFalse);
    barrier.complete();
    expect(await item, 'targeted');
    await full;
    expect(fullStarted, isTrue);
  });

  test('failed full run falls back to the targeted request', () async {
    final coordinator = ReconciliationCoordinator<int, String>();
    final barrier = Completer<void>();
    var targetedCalls = 0;

    final full = coordinator.runFull(() async {
      await barrier.future;
      throw StateError('library unavailable');
    });
    final item = coordinator.runItem(
      7,
      reconcile: () async {
        targetedCalls++;
        return 'targeted';
      },
      readAfterFull: () async => 'local',
    );

    barrier.complete();
    await expectLater(full, throwsStateError);
    expect(await item, 'targeted');
    expect(targetedCalls, 1);
  });
}
