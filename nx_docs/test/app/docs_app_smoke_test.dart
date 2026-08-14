import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_docs/app/docs_app.dart';
import 'package:nx_docs/sync/fake/fake_document_workspace.dart';
import 'package:nx_docs/workspace/workspace_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/offline_fixtures.dart';

void main() {
  testWidgets('notes app renders the desktop or mobile shell', (tester) async {
    SharedPreferences.setMockInitialValues({
      PrefsKeys.userId: '1',
      PrefsKeys.backendPreset: BackendPreset.localhost.key,
    });

    final workspace = FakeDocumentWorkspace(documents: [offlineTestDocument()]);
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
          documentWorkspaceProvider.overrideWithValue(workspace),
        ],
        child: const NexusDocsApp(),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Nexus Docs'), findsWidgets);
  });
}
