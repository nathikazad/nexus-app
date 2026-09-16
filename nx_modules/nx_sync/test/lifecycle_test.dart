import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_sync/nx_sync.dart';

void main() {
  testWidgets('keeps remote stream across sync callback and timer changes', (
    tester,
  ) async {
    final remote = StreamController<String>();
    final firstCalls = <SyncReason>[];
    final secondCalls = <SyncReason>[];
    Future<void> first(SyncReason reason) async => firstCalls.add(reason);
    Future<void> second(SyncReason reason) async => secondCalls.add(reason);

    Widget host(AppSynchronize? synchronize, {Duration? interval}) =>
        AppSyncLifecycle(
          synchronize: synchronize,
          remoteChanges: remote.stream,
          checkInterval: interval,
          child: const SizedBox(),
        );

    await tester.pumpWidget(host(first));
    expect(firstCalls, [SyncReason.appStarted]);
    await tester.pumpWidget(host(second));
    expect(tester.takeException(), isNull);
    expect(secondCalls, [SyncReason.appStarted]);

    await tester.pumpWidget(host(second, interval: const Duration(minutes: 1)));
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
