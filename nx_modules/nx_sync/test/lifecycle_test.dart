import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_sync/nx_sync.dart';

void main() {
  testWidgets(
    'no polling; resume checks only after five minutes; push stays immediate',
    (tester) async {
      var now = DateTime(2026, 10, 17);
      final calls = <SyncReason>[];
      final remote = StreamController<String>();
      await tester.pumpWidget(
        AppSyncLifecycle(
          synchronize: (reason) async {
            calls.add(reason);
          },
          remoteChanges: remote.stream,
          now: () => now,
          child: const SizedBox(),
        ),
      );
      expect(calls, [SyncReason.appStarted]);
      await tester.pump(const Duration(minutes: 10));
      expect(calls, hasLength(1));
      Future<void> resume() async {
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
      }

      now = now.add(const Duration(minutes: 5));
      await resume();
      expect(calls, hasLength(1));
      now = now.add(const Duration(milliseconds: 1));
      await resume();
      expect(calls.last, SyncReason.appResumed);
      expect(calls, hasLength(2));
      now = now.add(const Duration(minutes: 4));
      remote.add('revision-2');
      await tester.pump();
      expect(calls, hasLength(3));
      now = now.add(const Duration(minutes: 2));
      await resume();
      expect(calls, hasLength(3));
      await tester.pumpWidget(const SizedBox());
      unawaited(remote.close());
      await tester.pump();
    },
  );

  testWidgets('failed checks do not suppress a resume retry', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      AppSyncLifecycle(
        synchronize: (_) async {
          calls++;
          if (calls == 1) throw StateError('offline');
        },
        child: const SizedBox(),
      ),
    );
    expect(calls, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(calls, 2);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('keeps remote stream across sync callback changes', (
    tester,
  ) async {
    final remote = StreamController<String>();
    final firstCalls = <SyncReason>[];
    final secondCalls = <SyncReason>[];
    Future<void> first(SyncReason reason) async => firstCalls.add(reason);
    Future<void> second(SyncReason reason) async => secondCalls.add(reason);

    Widget host(AppSynchronize? synchronize) => AppSyncLifecycle(
      synchronize: synchronize,
      remoteChanges: remote.stream,
      child: const SizedBox(),
    );

    await tester.pumpWidget(host(first));
    expect(firstCalls, [SyncReason.appStarted]);
    await tester.pumpWidget(host(second));
    expect(tester.takeException(), isNull);
    expect(secondCalls, [SyncReason.appStarted]);

    await tester.pumpWidget(host(second));
    expect(tester.takeException(), isNull);
    remote.add('changed');
    await tester.pump();
    expect(secondCalls, [SyncReason.appStarted, SyncReason.timer]);
    expect(firstCalls, [SyncReason.appStarted]);

    await tester.pumpWidget(host(null));
    remote.add('while-disabled');
    await tester.pump();
    expect(secondCalls, hasLength(2));
    await tester.pumpWidget(host(second));
    remote.add('after-reenabled');
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(secondCalls.last, SyncReason.timer);

    await tester.pumpWidget(const SizedBox());
    expect(remote.hasListener, isFalse);
    unawaited(remote.close());
    await tester.pump();
  });
}
