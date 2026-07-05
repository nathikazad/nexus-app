import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_db/riverpod.dart';
import 'package:nx_post/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('renders feed shell and opens compose sheet', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(
            () => AuthController(
              initialDelay: Duration.zero,
              skipBackendPing: true,
            ),
          ),
          dbAuditSourceKindProvider.overrideWithValue('nx_post'),
        ],
        child: const NexusPostApp(),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('nx_post'), findsOneWidget);
    expect(find.text('Log In'), findsOneWidget);

    await tester.tap(find.text('Log In'));
    await tester.pump();

    expect(find.text('Feed'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('New microblog'), findsOneWidget);
    expect(find.text('Save microblog'), findsOneWidget);
  });
}
