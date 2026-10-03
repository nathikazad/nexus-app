import 'package:nx_time/data/domains/domain_appearance.dart';
import '../../_support/test_domains.dart';
import '../../_support/mock_graphql_client.dart';
import 'package:nx_time/data/domains/domain_workspace.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_time/domain/calendar/calendar_entry.dart';
import 'package:nx_time/features/calendar/calendar_page.dart';

CalendarEntry entry(String kind, String status) => CalendarEntry(
  id: 1,
  kind: kind,
  modelType: kind == 'task' ? 'Task' : 'Meet',
  name: 'Example',
  attributes: {
    if (kind == 'task') 'status': status else 'planning_status': status,
  },
);
void main() {
  test('planning excludes resolved tasks and actual activities', () {
    expect(isPlanningEntry(entry('task', 'todo')), isTrue);
    expect(isPlanningEntry(entry('task', 'progress')), isTrue);
    for (final status in ['done', 'skip'])
      expect(isPlanningEntry(entry('task', status)), isFalse);
    expect(isPlanningEntry(entry('action', 'planned')), isTrue);
    for (final status in ['attended', 'skipped', 'cancelled'])
      expect(isPlanningEntry(entry('action', status)), isFalse);
    expect(isPlanningEntry(entry('event', '')), isTrue);
    expect(isPlanningEntry(entry('birthday', '')), isTrue);
  });
  testWidgets('week calendar shows upcoming plans and hides completed tasks', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          domainAppearancesProvider.overrideWith((ref) async => {}),
          timeDomainsProvider.overrideWith(
            () => TestDomains(MockGraphQLClient()),
          ),
          planningFeedProvider.overrideWith(
            (ref) async => CalendarFeed(
              entries: [
                CalendarEntry(
                  id: 1,
                  kind: 'task',
                  modelType: 'Task',
                  name: 'Upcoming chore',
                  start: PlanningWeek.monday(DateTime.now()),
                  attributes: {'status': 'todo'},
                ),
                CalendarEntry(
                  id: 2,
                  kind: 'task',
                  modelType: 'Task',
                  name: 'Finished chore',
                  start: PlanningWeek.monday(DateTime.now()),
                  attributes: {'status': 'done'},
                ),
              ],
            ),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: CalendarPage())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Your plans this week'), findsOneWidget);
    expect(find.text('Upcoming chore'), findsOneWidget);
    expect(find.text('Finished chore'), findsNothing);
    expect(find.text('No plans'), findsNothing);
    expect(find.byTooltip('Next week'), findsOneWidget);
  });
}
