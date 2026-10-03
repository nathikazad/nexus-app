import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_time/domain/tasks/task.dart';
import 'package:nx_time/domain/tasks/task_status.dart';
import 'package:nx_time/features/tasks/task_view_models.dart';
import 'package:nx_time/features/tasks/recently_completed_tasks.dart';
import 'package:nx_time/data/domains/domain_workspace.dart';
import 'package:nx_time/data/domains/domain_appearance.dart';

class _NoWorkspace extends TimeDomains {
  @override
  Future<DomainWorkspace> build() => Future.error('No workspace in fixture');
}

void main() {
  test('main list excludes only explicit false on shared tasks', () {
    const unassigned = Task(id: 1, name: 'Task', modelTypeId: 1);
    const assigned = Task(
      id: 2,
      name: 'Shared',
      modelTypeId: 1,
      participants: {
        '3': {'assigned': true},
        '1': {'rank': 'U'},
        '2': {'assigned': false},
      },
    );
    expect(taskInMainList(unassigned, personal: true, userId: '3'), isTrue);
    expect(taskInMainList(unassigned, personal: false, userId: '3'), isTrue);
    expect(taskInMainList(assigned, personal: false, userId: '3'), isTrue);
    expect(taskInMainList(assigned, personal: false, userId: '1'), isTrue);
    expect(taskInMainList(assigned, personal: false, userId: '2'), isFalse);
    expect(taskInMainList(assigned, personal: true, userId: '2'), isTrue);
  });
  final today = DateTime(2026, 10, 3);
  Task task(
    int id,
    DateTime? completed, {
    TaskStatus status = TaskStatus.done,
  }) => Task(
    id: id,
    name: 'Finished $id',
    modelTypeId: 1,
    completedAt: completed,
    dueAt: DateTime(2025, 1, 1),
    status: status,
  );
  test(
    'recent completion window uses completion, excludes open/old/future tasks, sorts newest first',
    () {
      final result = recentlyCompletedTasks([
        task(1, DateTime(2026, 10, 2)),
        task(2, DateTime(2026, 10, 3, 18)),
        task(3, DateTime(2026, 10, 1, 23, 59)),
        task(4, DateTime(2026, 10, 4)),
        task(5, null),
        task(6, DateTime(2026, 10, 3), status: TaskStatus.todo),
        task(7, DateTime(2026, 10, 3), status: TaskStatus.skip),
      ], today);
      expect(result.map((t) => t.id), [2, 1]);
    },
  );
  testWidgets('shows five recent completions, expands remaining ones', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskCalendarDayProvider.overrideWithValue(today),
          timeDomainsProvider.overrideWith(_NoWorkspace.new),
          domainAppearancesProvider.overrideWith((ref) async => {}),
          recentlyCompletedTasksProvider.overrideWith(
            (ref) async => [
              for (var i = 0; i < 7; i++)
                task(i, DateTime(2026, 10, 3, 12 - i)),
            ],
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: RecentlyCompletedTasks()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Finished 4'), findsOneWidget);
    expect(find.text('Finished 5'), findsNothing);
    await tester.ensureVisible(find.text('Show 2 more'));
    await tester.tap(find.text('Show 2 more'));
    await tester.pumpAndSettle();
    expect(find.text('Finished 6'), findsOneWidget);
  });
}
