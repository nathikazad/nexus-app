import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_offline/nx_offline.dart';

void main() {
  testWidgets('reports startup, resume, and restored connectivity', (
    tester,
  ) async {
    final connectivity = StreamController<bool>();
    addTearDown(connectivity.close);
    final reasons = <SyncReason>[];

    await tester.pumpWidget(
      MaterialApp(
        home: OfflineLifecycle(
          synchronize: (reason) async => reasons.add(reason),
          onlineChanges: connectivity.stream,
          child: const Text('App'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(reasons, [SyncReason.appStarted]);

    connectivity.add(false);
    await tester.pumpAndSettle();
    expect(reasons, [SyncReason.appStarted]);

    connectivity.add(true);
    await tester.pumpAndSettle();
    expect(reasons, [SyncReason.appStarted, SyncReason.connectivityRestored]);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(reasons.last, SyncReason.appResumed);
  });

  testWidgets('a disabled lifecycle does not synchronize', (tester) async {
    final connectivity = StreamController<bool>();
    addTearDown(connectivity.close);

    await tester.pumpWidget(
      MaterialApp(
        home: OfflineLifecycle(
          synchronize: null,
          onlineChanges: connectivity.stream,
          child: const Text('Web app'),
        ),
      ),
    );
    connectivity.add(true);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.text('Web app'), findsOneWidget);
  });

  testWidgets('status view exposes current synchronization state', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final source = _StatusSource();
    addTearDown(source.close);

    await tester.pumpWidget(MaterialApp(home: SyncStatusView(source: source)));

    expect(find.text('Saved locally'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('Synchronization status')),
      findsOneWidget,
    );
    semantics.dispose();
  });
}

final class _StatusSource implements SyncStatusSource {
  final StreamController<SyncStatus> _changes =
      StreamController<SyncStatus>.broadcast();

  @override
  SyncStatus get status => const SyncStatus.idle();

  @override
  Stream<SyncStatus> get statusChanges => _changes.stream;

  Future<void> close() => _changes.close();
}
