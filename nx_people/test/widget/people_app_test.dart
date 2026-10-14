import 'package:nx_people/features/assistant/people_assistant.dart';
import 'package:nx_people/data/meeting/meeting_list.dart';
import 'package:nx_people/data/meeting/meeting_transcripts.dart';
import 'dart:async';
import 'package:nx_people/features/shell/people_state.dart';
import 'package:nx_people/domain/person/person.dart';
import 'package:nx_people/data/sync/people_sync_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_people/app.dart';
import 'package:nx_people/data/auth/people_auth_controller.dart';
import 'package:nx_people/data/fake_people_repository.dart';
import 'package:nx_people/data/providers.dart';
import 'package:nx_people/domain/log/daily_log.dart';
import 'package:nx_people/domain/log/log_repository.dart';
import 'package:nx_people/domain/meeting/meeting_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<_FakeLogRepository> pumpApp(
    WidgetTester tester,
    Size size, {
    FakePeopleRepository? people,
    bool failDomainSwitch = false,
  }) async {
    var domainLoads = 0;
    final logs = _FakeLogRepository();
    final meetings = _FakeMeetingRepository();
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          domainLoaderProvider.overrideWithValue((_) async {
            if (failDomainSwitch && domainLoads++ > 0) {
              throw StateError('offline');
            }
            return [
              const DomainMembership(
                id: 1,
                name: 'Personal',
                role: 'owner',
                kind: 'personal',
              ),
              const DomainMembership(id: 2, name: 'Home', role: 'owner'),
            ];
          }),
          allMeetingsProvider.overrideWith(
            (ref) async => [
              PersonMeeting(
                id: 99,
                name: 'Weekly Planning',
                startTime: DateTime.now(),
                description: 'Caught up with Maya',
              ),
            ],
          ),
          meetingTranscriptsProvider(99).overrideWith(
            (ref) =>
                Stream.value(const MeetingTranscriptState([], connected: true)),
          ),
          peopleDataSessionProvider.overrideWithValue(null),
          peopleOfflineStoreProvider.overrideWithValue(null),
          authProvider.overrideWith(
            () => PeopleAuthController(
              initialUser: User(
                userId: '1',
                domainId: 1,
                preset: BackendPreset.defaultPreset,
              ),
              skipBackendPing: true,
            ),
          ),
          peopleRepositoryProvider.overrideWithValue(
            people ?? FakePeopleRepository(),
          ),
          logRepositoryProvider.overrideWithValue(logs),
          meetingRepositoryProvider.overrideWithValue(meetings),
        ],
        child: const NexusPeopleApp(),
      ),
    );
    await tester.pumpAndSettle();
    return logs;
  }

  testWidgets(
    'Recent is selected and sync preserves the visible scrolling list',
    (tester) async {
      final repository = _RefreshingPeopleRepository();
      await pumpApp(tester, const Size(390, 500), people: repository);
      expect(find.text('RECENT CONTACTS'), findsNothing);
      final scrollable = find
          .descendant(
            of: find.byKey(const PageStorageKey('people-list')),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.drag(scrollable, const Offset(0, -180));
      await tester.pumpAndSettle();
      final before = tester.state<ScrollableState>(scrollable).position.pixels;
      expect(before, greaterThan(0));
      repository.pending = Completer<List<Person>>();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(NexusPeopleApp)),
      );
      container.read(peopleDataGenerationProvider.notifier).changed();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.state<ScrollableState>(scrollable).position.pixels, before);
      repository.pending!.complete(await FakePeopleRepository().listRecent());
      await tester.pumpAndSettle();
      expect(tester.state<ScrollableState>(scrollable).position.pixels, before);
      await tester.drag(scrollable, const Offset(0, 500));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('desktop renders four section nav, people list, and profile', (
    tester,
  ) async {
    await pumpApp(tester, const Size(1200, 800));

    expect(find.text('nx_people'), findsOneWidget);
    expect(find.text('People'), findsWidgets);
    expect(find.text('Meetings'), findsWidgets);
    expect(find.text('Events'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Funnels'), findsNothing);
    expect(find.text('Sarah Chen'), findsWidgets);
    expect(find.text('NEXT ACTION'), findsNothing);
    expect(find.text('No meetings yet'), findsOneWidget);
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

  testWidgets('people list follows the uncluttered Aura layout', (
    tester,
  ) async {
    await pumpApp(tester, const Size(390, 844));
    expect(find.text('RECENT CONTACTS'), findsNothing);
    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.byKey(const ValueKey('people-filter-button')), findsNothing);
    expect(find.text('Search'), findsOneWidget);
  });

  testWidgets('mobile adds a person from people tab', (tester) async {
    await pumpApp(tester, const Size(390, 844));

    expect(find.byKey(const ValueKey('people-create-button')), findsNothing);
    expect(find.byKey(const ValueKey('people-menu-button')), findsNothing);

    ProviderScope.containerOf(
      tester.element(find.byType(NexusPeopleApp)),
    ).read(peopleWorkspaceProvider.notifier).setSection(PeopleAppSection.logs);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('logs-create-button')));
    await tester.pumpAndSettle();

    expect(find.text('Create'), findsOneWidget);
    expect(find.text('Person'), findsOneWidget);
    expect(find.text('Meeting'), findsOneWidget);
    expect(find.text('Log'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('create-person-option')));
    await tester.pumpAndSettle();

    expect(find.text('Add Person'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('person-name-field')),
      'Jane Doe',
    );
    expect(find.byKey(const ValueKey('person-company-field')), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('person-summary-field')),
      'Met through the people app redesign.',
    );
    await tester.enterText(
      find.byKey(const ValueKey('person-desires-field')),
      'PCB hiring context\nSales introductions',
    );
    await tester.tap(find.byKey(const ValueKey('person-save-button')));
    await tester.pumpAndSettle();

    expect(find.text('Add Person'), findsNothing);
    await tester.tap(find.text('People'));
    await tester.pumpAndSettle();
    expect(find.text('Jane Doe'), findsOneWidget);

    await tester.tap(find.text('Jane Doe'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Background'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('PCB hiring context', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('creates a text Daily Log and offers image attachment', (
    tester,
  ) async {
    final logs = await pumpApp(tester, const Size(390, 844));

    ProviderScope.containerOf(
      tester.element(find.byType(NexusPeopleApp)),
    ).read(peopleWorkspaceProvider.notifier).setSection(PeopleAppSection.logs);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('logs-create-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('create-log-option')));
    await tester.pumpAndSettle();

    expect(find.text('Add Log'), findsOneWidget);
    expect(find.byKey(const ValueKey('log-add-image-button')), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('log-entry-field')),
      'Quick relationship note.',
    );
    await tester.tap(find.byKey(const ValueKey('log-save-button')));
    await tester.pumpAndSettle();

    expect(find.text('Add Log'), findsNothing);
    expect(logs.created, hasLength(1));
    expect(logs.created.single.entry, 'Quick relationship note.');
    expect(logs.created.single.imageUrl, isNull);
  });

  testWidgets('mobile top action logs out', (tester) async {
    await pumpApp(tester, const Size(390, 844));

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Funnels'), findsNothing);
    expect(find.text('Log out'), findsOneWidget);
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();

    expect(find.text('nx_people'), findsOneWidget);
    expect(find.text('Log In'), findsOneWidget);
    expect(find.byKey(const ValueKey('people-add-fab')), findsNothing);
  });

  testWidgets('Settings replaces Logs and switches domain', (tester) async {
    await pumpApp(tester, const Size(390, 844));
    expect(find.text('Logs'), findsNothing);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('SWITCH DOMAIN'), findsOneWidget);
    expect(find.text('Personal'), findsOneWidget);
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(NexusPeopleApp)),
    );
    expect(container.read(authProvider).value?.domainId, 2);
    expect(container.read(authProvider).value?.domainName, 'Home');
  });

  testWidgets('failed domain switch preserves current session', (tester) async {
    await pumpApp(tester, const Size(390, 844), failDomainSwitch: true);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.text('Could not switch domain. Please retry.'), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(NexusPeopleApp)),
    );
    expect(container.read(authProvider).value?.domainId, 1);
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
    expect(find.byKey(const ValueKey('person-company-field')), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('person-summary-field')),
      'Updated relationship notes.',
    );
    await tester.enterText(
      find.byKey(const ValueKey('person-desires-field')),
      'Software Engineer candidates',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('person-tag-delete-Location-SF')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('person-tag-delete-Location-SF')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add tag').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sales').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('person-save-button')));
    await tester.pumpAndSettle();

    expect(find.text('Edit Person'), findsNothing);
    expect(find.text('Sarah Chen Updated'), findsOneWidget);
    await tester.tap(find.text('Background'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Updated relationship notes.', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('Software Engineer candidates', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Sales'), findsOneWidget);
    expect(find.text('SF'), findsNothing);
  });

  testWidgets('profile adds a tag from the main profile page', (tester) async {
    await pumpApp(tester, const Size(390, 844));

    await tester.tap(find.text('Sarah Chen').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Background'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add tag'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sales').last);
    await tester.pumpAndSettle();

    expect(find.text('Sales'), findsOneWidget);
  });

  testWidgets('meetings tab opens the meeting notes and transcript', (
    tester,
  ) async {
    await pumpApp(tester, const Size(1200, 800));

    await tester.tap(find.text('Meetings').first);
    await tester.pumpAndSettle();

    expect(find.byTooltip('Choose date'), findsOneWidget);
    expect(find.text('Meetings'), findsWidgets);
    expect(find.textContaining('Caught up with Maya'), findsOneWidget);
    expect(find.text('Weekly Planning'), findsWidgets);

    await tester.tap(find.text('Weekly Planning').first);
    await tester.pumpAndSettle();

    expect(find.text('No recording attached to this meeting.'), findsOneWidget);
    expect(find.text('NEXT ACTION'), findsNothing);
    expect(
      tester
          .widget<PeopleAssistantButton>(
            find.byType(PeopleAssistantButton).last,
          )
          .selection!
          .id,
      99,
    );
  });

  testWidgets('mobile uses bottom tabs and pushes profile detail', (
    tester,
  ) async {
    await pumpApp(tester, const Size(390, 844));

    expect(find.text('People'), findsWidgets);
    expect(find.text('Meetings'), findsWidgets);
    expect(find.text('Events'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    final mainAi = find.byType(PeopleAssistantButton);
    expect(tester.getCenter(mainAi).dx, closeTo(195, 1));
    expect(tester.widget<PeopleAssistantButton>(mainAi).selection, isNull);
    await tester.tap(mainAi);
    await tester.pumpAndSettle();
    expect(find.text('People assistant'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sarah Chen').first);
    await tester.pumpAndSettle();

    final profileAi = find.byType(PeopleAssistantButton).last;
    expect(
      tester.widget<PeopleAssistantButton>(profileAi).selection!.name,
      'Sarah Chen',
    );
    expect(tester.getCenter(profileAi).dx, greaterThan(300));
    expect(find.text('Background'), findsOneWidget);
    expect(find.text('Meetings').last, findsOneWidget);
    expect(find.text('Background'), findsOneWidget);

    await tester.tap(find.text('Background'));
    await tester.pumpAndSettle();
    expect(find.text('EXPERIENCE'), findsOneWidget);
    expect(find.text('EDUCATION'), findsWidgets);
    expect(find.text('NEXT ACTION'), findsNothing);

    await tester.tap(find.text('Meetings').last);
    await tester.pumpAndSettle();
    expect(find.text('NEXT ACTION'), findsNothing);
    expect(find.text('No meetings yet'), findsOneWidget);
  });
}

class _FakeLogRepository implements LogRepository {
  final List<DailyLogDraft> created = <DailyLogDraft>[];

  @override
  Future<List<DailyLog>> listForCalendarDay(DateTime dayLocal) async =>
      const <DailyLog>[];

  @override
  Future<int> create(DailyLogDraft draft) async {
    created.add(draft);
    return created.length;
  }
}

class _FakeMeetingRepository implements MeetingRepository {
  final List<MeetingDraft> created = <MeetingDraft>[];

  @override
  Future<int> create(MeetingDraft draft) async {
    created.add(draft);
    return created.length;
  }
}

class _RefreshingPeopleRepository extends FakePeopleRepository {
  Completer<List<Person>>? pending;
  @override
  Future<List<Person>> listRecent({int limit = 20}) =>
      pending?.future ?? super.listRecent(limit: limit);
}
