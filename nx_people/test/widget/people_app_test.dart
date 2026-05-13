import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_people/app.dart';
import 'package:nx_people/data/auth/people_auth_controller.dart';
import 'package:nx_people/data/fake_people_repository.dart';
import 'package:nx_people/data/providers.dart';

void main() {
  Future<void> pumpDesktop(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(
            () => PeopleAuthController(
              initialUser: User(
                userId: '1',
                preset: BackendPreset.defaultPreset,
              ),
              skipBackendPing: true,
            ),
          ),
          peopleRepositoryProvider.overrideWithValue(
            const FakePeopleRepository(),
          ),
        ],
        child: const NexusPeopleApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('people app renders the desktop navigator and profile', (
    tester,
  ) async {
    await pumpDesktop(tester);

    expect(find.text('nx_people'), findsOneWidget);
    expect(find.text('People'), findsOneWidget);
    expect(find.text('Tags'), findsOneWidget);
    expect(find.text('Sarah Chen'), findsWidgets);
    expect(find.text('INSPECTOR'), findsOneWidget);
  });

  testWidgets('sidebar search opens results and preserves context after open', (
    tester,
  ) async {
    await pumpDesktop(tester);

    await tester.enterText(
      find.byKey(const ValueKey('people-search-field')),
      'atlas',
    );
    await tester.pumpAndSettle();

    expect(find.text('Search: atlas'), findsOneWidget);
    expect(find.text('2 people'), findsOneWidget);
    expect(find.text('Daniel Brooks'), findsOneWidget);

    await tester.tap(find.text('Daniel Brooks').last);
    await tester.pumpAndSettle();

    expect(find.text('Daniel Brooks'), findsWidgets);
    expect(find.text('Back to Search: atlas'), findsOneWidget);
    expect(find.text('2 of 2'), findsOneWidget);
  });

  testWidgets('tags tab shows tag groups and opens matching result overlay', (
    tester,
  ) async {
    await pumpDesktop(tester);

    await tester.tap(find.text('Tags'));
    await tester.pumpAndSettle();

    expect(find.text('RELATIONSHIP'), findsOneWidget);
    expect(find.text('Investor'), findsWidgets);

    await tester.tap(find.text('Investor').first);
    await tester.pumpAndSettle();

    expect(find.text('Relationship: Investor'), findsOneWidget);
    expect(find.text('2 people'), findsOneWidget);
    expect(find.text('Marcus Rivera'), findsWidgets);
  });
}
