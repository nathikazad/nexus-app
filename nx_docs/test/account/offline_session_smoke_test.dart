import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_docs/app/docs_app.dart';
import 'package:nx_docs/sync/fake/fake_document_workspace.dart';
import 'package:nx_docs/account/account_session.dart';
import 'package:nx_docs/account/account_providers.dart';
import 'package:nx_docs/workspace/workspace_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/offline_fixtures.dart';

void main() {
  testWidgets(
    'cached account opens the notes shell while auth is unavailable',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      const session = CachedSession(userId: '1', backendPreset: 'localhost');
      final workspace = FakeDocumentWorkspace(
        documents: [offlineTestDocument()],
      );
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
            documentWorkspaceProvider.overrideWithValue(workspace),
          ],
          child: const NexusDocsApp(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Nexus Docs'), findsWidgets);
    },
  );
}
