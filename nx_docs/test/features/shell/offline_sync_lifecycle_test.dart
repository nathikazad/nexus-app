import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_docs/composition/offline_providers.dart';
import 'package:nx_docs/features/shell/offline_sync_lifecycle.dart';
import 'package:nx_offline/nx_offline.dart';

void main() {
  testWidgets('web policy does not initialize the offline lifecycle', (
    tester,
  ) async {
    var workspaceReads = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          offlineEnabledProvider.overrideWithValue(false),
          notesWorkspaceProvider.overrideWith((ref) {
            workspaceReads++;
            return null;
          }),
        ],
        child: const MaterialApp(
          home: OfflineSyncLifecycle(child: Text('Web notes')),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Web notes'), findsOneWidget);
    expect(workspaceReads, 0);
  });

  testWidgets('native wiring forwards lifecycle reasons exactly once', (
    tester,
  ) async {
    final connectivity = StreamController<bool>();
    addTearDown(connectivity.close);
    final reasons = <SyncReason>[];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          offlineLifecycleSyncProvider.overrideWithValue(
            (reason) async => reasons.add(reason),
          ),
          offlineConnectivityChangesProvider.overrideWithValue(
            connectivity.stream,
          ),
        ],
        child: const MaterialApp(
          home: OfflineSyncLifecycle(child: Text('Native notes')),
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
    expect(reasons.last, SyncReason.connectivityRestored);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(reasons.last, SyncReason.appResumed);
    expect(reasons, hasLength(3));
  });
}
