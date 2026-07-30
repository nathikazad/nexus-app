import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_notes/composition/offline_providers.dart';
import 'package:nx_notes/features/shell/offline_sync_lifecycle.dart';

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
}
