import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_notes/app.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('notes app renders the desktop or mobile shell', (tester) async {
    SharedPreferences.setMockInitialValues({
      PrefsKeys.userId: '1',
      PrefsKeys.backendPreset: BackendPreset.localhost.key,
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(
            () => AuthController(
              initialDelay: Duration.zero,
              skipBackendPing: true,
            ),
          ),
        ],
        child: const NexusNotesApp(),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('nx_notes'), findsWidgets);
  });
}
