@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nx_time/features/auth/time_login_screen.dart';

void main() {
  testWidgets('TL12.1 TimeLoginScreen builds with form fields', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(
          () => AuthController(
            initialDelay: Duration.zero,
            skipBackendPing: true,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: TimeLoginScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Log In'), findsOneWidget);
    expect(find.text('Nathik'), findsOneWidget);
    expect(find.text('Yareni'), findsNothing);
    expect(find.byType(TextFormField), findsNothing);
    expect(
      find.byType(DropdownButtonFormField<AuthLoginProfile>),
      findsOneWidget,
    );
    expect(find.byType(DropdownButtonFormField<BackendPreset>), findsOneWidget);
  });
}
