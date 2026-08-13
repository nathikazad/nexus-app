import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_docs/app.dart';
import 'package:nx_docs/application/fake/fake_notes_workspace.dart';
import 'package:nx_docs/application/ports/session_store.dart';
import 'package:nx_docs/composition/offline_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/offline_fixtures.dart';

void main() {
  testWidgets(
    'cached account opens the notes shell while auth is unavailable',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      const session = CachedSession(userId: '1', backendPreset: 'localhost');
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
            activeOfflineSessionProvider.overrideWith((ref) async => session),
            notesWorkspaceProvider.overrideWithValue(workspace),
          ],
          child: const NexusNotesApp(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Nexus Docs'), findsWidgets);
    },
  );
}
