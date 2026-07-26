import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_offline/nx_offline.dart';

import '../support/fakes.dart';

void main() {
  testWidgets('syncs on startup and restored connectivity', (tester) async {
    const account = AccountScope(
      backend: 'production',
      userId: 'user-1',
      application: 'test',
    );
    final transport = FakeTransport();
    final connectivity = StreamController<bool>();
    addTearDown(connectivity.close);
    final coordinator = SyncCoordinator(
      store: MemorySyncStore(account),
      transport: transport,
      collections: [
        FakeCollection('items', {'Item'}),
      ],
      clock: FakeClock(DateTime.utc(2026, 7, 26)),
      idGenerator: SequenceIds(),
    );
    addTearDown(coordinator.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: OfflineLifecycle(
          coordinator: coordinator,
          onlineChanges: connectivity.stream,
          child: const Text('App'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(transport.pullCount, 1);

    connectivity.add(false);
    await tester.pumpAndSettle();
    expect(transport.pullCount, 1);

    connectivity.add(true);
    await tester.pumpAndSettle();
    expect(transport.pullCount, 2);
  });

  testWidgets('status view exposes current synchronization state', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    const account = AccountScope(
      backend: 'production',
      userId: 'user-1',
      application: 'test',
    );
    final transport = FakeTransport();
    final coordinator = SyncCoordinator(
      store: MemorySyncStore(account),
      transport: transport,
      collections: [
        FakeCollection('items', {'Item'}),
      ],
      clock: FakeClock(DateTime.utc(2026, 7, 26)),
      idGenerator: SequenceIds(),
    );
    addTearDown(coordinator.dispose);

    await tester.pumpWidget(
      MaterialApp(home: SyncStatusView(coordinator: coordinator)),
    );

    expect(find.text('Saved locally'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('Synchronization status')),
      findsOneWidget,
    );
    semantics.dispose();
  });
}
