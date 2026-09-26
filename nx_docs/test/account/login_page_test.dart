import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_docs/account/login_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final savedId in [null, '2']) {
    testWidgets('Docs account choice with saved account $savedId', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        if (savedId != null) PrefsKeys.lastUserId: savedId,
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(
              () => AuthController(initialDelay: Duration.zero),
            ),
          ],
          child: const MaterialApp(home: DocsLoginPage()),
        ),
      );
      await tester.pumpAndSettle();
      final person = find.byType(DropdownButtonFormField<AuthLoginProfile>);
      expect(
        tester.state<FormFieldState<AuthLoginProfile>>(person).value?.userId,
        savedId,
      );
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      if (savedId == null) {
        expect(button.onPressed, isNull);
        await tester.tap(person);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Yareni').last);
        await tester.pumpAndSettle();
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNotNull,
        );
      } else {
        expect(button.onPressed, isNotNull);
        expect(find.text('Yareni'), findsOneWidget);
      }
    });
  }
}
