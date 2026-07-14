import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_people/app.dart';
import 'package:nx_people/data/auth/people_auth_controller.dart';
import 'package:nx_people/data/fake_people_repository.dart';
import 'package:nx_people/data/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester, Size size) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = size;
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
          peopleRepositoryProvider.overrideWithValue(FakePeopleRepository()),
        ],
        child: const NexusPeopleApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('desktop renders four section nav, people list, and profile', (
    tester,
  ) async {
    await pumpApp(tester, const Size(1200, 800));

    expect(find.text('nx_people'), findsOneWidget);
    expect(find.text('People'), findsWidgets);
    expect(find.text('Meetings'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('Funnels'), findsOneWidget);
    expect(find.text('Sarah Chen'), findsWidgets);
    expect(find.text('NEXT ACTION'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('TIMELINE AND MEETINGS'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('TIMELINE AND MEETINGS'), findsOneWidget);
  });

  testWidgets('desktop resolves and creates LinkedIn suggestions', (
    tester,
  ) async {
    await pumpApp(tester, const Size(1200, 800));

    await tester.tap(find.text('Background'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('LINKEDIN SUGGESTIONS'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Product Lead'), findsWidgets);
    expect(find.text('Northstar Labs'), findsWidgets);
    expect(find.text('WORK'), findsNothing);

    await tester.ensureVisible(
      find.byKey(const ValueKey('suggestions-toggle')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('suggestions-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('WORK'), findsOneWidget);
    expect(find.text('EDUCATION'), findsWidgets);

    await tester.ensureVisible(
      find.byKey(const ValueKey('suggestion-use-work-0-301')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('suggestion-use-work-0-301')));
    await tester.pumpAndSettle();
    expect(find.text('Resolved to Northstar Labs'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('suggestion-create-education-0')),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(
      find.byKey(const ValueKey('suggestion-create-education-0')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Created Stanford University'), findsOneWidget);
  });

  testWidgets('people search filters across the repository', (tester) async {
    await pumpApp(tester, const Size(1200, 800));

    await tester.enterText(
      find.byKey(const ValueKey('people-search-field')),
      'atlas',
    );
    await tester.pumpAndSettle();

    expect(find.text('Marcus Rivera'), findsWidgets);
    expect(find.text('Daniel Brooks'), findsWidgets);
    expect(find.text('Sarah Chen'), findsNothing);
  });

  testWidgets('mobile people tab shows corrected filter pills', (tester) async {
    await pumpApp(tester, const Size(390, 844));

    expect(find.text('Pinned'), findsOneWidget);
    expect(find.text('Recent'), findsOneWidget);
    expect(find.text('Follow up'), findsWidgets);
    expect(find.text('Company'), findsNothing);
    expect(find.text('RECENTLY CONTACTED'), findsNothing);
    expect(find.text('Active'), findsNothing);
    expect(find.byKey(const ValueKey('person-pending-dot-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('person-pending-dot-4')), findsNothing);
    expect(find.text('Unknown'), findsNothing);
    expect(find.text('2026-07-05'), findsOneWidget);
  });

  testWidgets('mobile people filter button opens bottom sheet', (tester) async {
    await pumpApp(tester, const Size(390, 844));

    await tester.tap(find.byKey(const ValueKey('people-filter-button')));
    await tester.pumpAndSettle();

    expect(find.text('Filter & Sort'), findsOneWidget);
    expect(find.text('Sort By'), findsOneWidget);
    expect(find.text('Company'), findsOneWidget);
    expect(find.text('Role'), findsOneWidget);
    expect(find.text('Tags'), findsOneWidget);
    expect(find.text('Reset'), findsOneWidget);
    expect(find.text('Apply'), findsOneWidget);
  });

  testWidgets('mobile adds a person from people tab', (tester) async {
    await pumpApp(tester, const Size(390, 844));

    expect(find.byKey(const ValueKey('people-add-button')), findsNothing);
    expect(find.byKey(const ValueKey('people-logout-button')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('people-add-fab')));
    await tester.pumpAndSettle();

    expect(find.text('Add Person'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('person-name-field')),
      'Jane Doe',
    );
    await tester.enterText(
      find.byKey(const ValueKey('person-company-field')),
      'Quiet Ventures',
    );
    await tester.enterText(
      find.byKey(const ValueKey('person-summary-field')),
      'Met through the people app redesign.',
    );
    await tester.tap(find.byKey(const ValueKey('person-save-button')));
    await tester.pumpAndSettle();

    expect(find.text('Add Person'), findsNothing);
    expect(find.text('Jane Doe'), findsOneWidget);
    expect(find.text('Quiet Ventures'), findsOneWidget);
  });

  testWidgets('mobile top action logs out', (tester) async {
    await pumpApp(tester, const Size(390, 844));

    await tester.tap(find.byKey(const ValueKey('people-logout-button')));
    await tester.pumpAndSettle();

    expect(find.text('nx_people'), findsOneWidget);
    expect(find.text('Log In'), findsOneWidget);
    expect(find.byKey(const ValueKey('people-add-fab')), findsNothing);
  });

  testWidgets('mobile edits a person from profile detail', (tester) async {
    await pumpApp(tester, const Size(390, 844));

    await tester.tap(find.text('Sarah Chen').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Person'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('person-name-field')),
      'Sarah Chen Updated',
    );
    await tester.enterText(
      find.byKey(const ValueKey('person-company-field')),
      'Northstar Labs Updated',
    );
    await tester.enterText(
      find.byKey(const ValueKey('person-summary-field')),
      'Updated relationship notes.',
    );
    await tester.tap(find.byKey(const ValueKey('person-save-button')));
    await tester.pumpAndSettle();

    expect(find.text('Edit Person'), findsNothing);
    expect(find.text('Sarah Chen Updated'), findsOneWidget);
    expect(find.text('Northstar Labs Updated'), findsOneWidget);
    expect(
      find.textContaining('Updated relationship notes.', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('meetings tab shows date agenda and opens person detail', (
    tester,
  ) async {
    await pumpApp(tester, const Size(1200, 800));

    await tester.tap(find.text('Meetings'));
    await tester.pumpAndSettle();

    expect(find.text('Today'), findsWidgets);
    expect(find.text('Meetings'), findsWidgets);
    expect(find.text('People touched'), findsOneWidget);
    expect(find.text('Weekly Planning'), findsWidgets);

    await tester.tap(find.text('Weekly Planning').first);
    await tester.pumpAndSettle();

    expect(find.text('Maya Ioseliani'), findsWidgets);
    expect(find.text('NEXT ACTION'), findsOneWidget);
  });

  testWidgets('mobile uses bottom tabs and pushes profile detail', (
    tester,
  ) async {
    await pumpApp(tester, const Size(390, 844));

    expect(find.text('People'), findsWidgets);
    expect(find.text('Meetings'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('Funnels'), findsOneWidget);

    await tester.tap(find.text('Sarah Chen').first);
    await tester.pumpAndSettle();

    expect(find.text('PROFILE'), findsOneWidget);
    expect(find.text('Activity'), findsOneWidget);
    expect(find.text('Background'), findsOneWidget);

    await tester.tap(find.text('Background'));
    await tester.pumpAndSettle();
    expect(find.text('EXPERIENCE'), findsOneWidget);
    expect(find.text('EDUCATION'), findsWidgets);
    expect(find.text('NEXT ACTION'), findsNothing);

    await tester.tap(find.text('Activity'));
    await tester.pumpAndSettle();
    expect(find.text('NEXT ACTION'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('TIMELINE AND MEETINGS'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('TIMELINE AND MEETINGS'), findsOneWidget);
  });
}
