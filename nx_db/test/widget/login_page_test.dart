@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test/test.dart' show Tags;

import 'package:nx_db/nx_db.dart';

void main() {
  testWidgets('LP12.1 LoginPage builds with form fields', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(
          () => AuthController(initialDelay: Duration.zero, skipBackendPing: true),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: LoginPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Login'), findsWidgets);
    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<BackendPreset>), findsOneWidget);
  });

  testWidgets('LP12.2 onLoginSuccess receives resolved urls', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(
          () => AuthController(initialDelay: Duration.zero, skipBackendPing: true),
        ),
      ],
    );
    addTearDown(container.dispose);

    BackendUrls? received;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: LoginPage(
            onLoginSuccess: (urls) => received = urls,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
    await tester.pumpAndSettle();

    expect(received, isNotNull);
    expect(received!.graphqlHttp, resolve(BackendPreset.piTailscale).graphqlHttp);
  });
}
