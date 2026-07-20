import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_notes/app.dart';
import 'package:nx_notes/application/ports/session_store.dart';
import 'package:nx_notes/composition/offline_providers.dart';
import 'package:nx_notes/data/document/fake_document_repository.dart';
import 'package:nx_notes/data/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'cached account opens the notes shell while auth is unavailable',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      const session = CachedSession(userId: '1', backendPreset: 'localhost');
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
            documentRepositoryProvider.overrideWithValue(
              FakeDocumentRepository(),
            ),
          ],
          child: const NexusNotesApp(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('nx_notes'), findsWidgets);
    },
  );
}
