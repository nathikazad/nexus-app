import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_notes/app.dart';
import 'package:nx_notes/application/fake/fake_notes_workspace.dart';
import 'package:nx_notes/composition/offline_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/offline_fixtures.dart';

void main() {
  testWidgets('notes app renders the desktop or mobile shell', (tester) async {
    SharedPreferences.setMockInitialValues({
      PrefsKeys.userId: '1',
      PrefsKeys.backendPreset: BackendPreset.localhost.key,
    });

    final workspace = FakeNotesWorkspace(documents: [offlineTestDocument()]);
    addTearDown(workspace.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(
            () => AuthController(
              initialDelay: Duration.zero,
              skipBackendPing: true,
            ),
          ),
          notesWorkspaceProvider.overrideWithValue(workspace),
        ],
        child: const NexusNotesApp(),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('nx_notes'), findsWidgets);
  });
}
