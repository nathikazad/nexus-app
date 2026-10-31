import 'package:nx_time/features/schedule/schedule_page.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_time/data/providers.dart';
import 'package:nx_time/features/calendar/calendar_feed_providers.dart';
import 'package:nx_time/features/calendar/calendar_providers.dart';
import 'package:nx_time/features/calendar/calendar_view_model.dart';
import 'package:nx_time/features/calendar/history_page.dart';
import 'package:nx_time/features/tasks/task_view_models.dart';
import 'package:nx_time/features/tasks/tasks_page.dart';
import 'package:nx_time/features/today/log_view_model.dart';
import 'package:nx_time/features/today/today_page.dart';
import 'package:nx_time/features/today/widgets/time_map_bar.dart';
import 'package:nx_time/features/today/widgets/today_view_toggle.dart';

import '../_support/screenshot_today_snapshot.dart';

void main() {
  testWidgets('Actions combines both periods and all modes on a phone layout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [
        schedulePlansProvider.overrideWith((ref) async => []),
        modelTypeColorsProvider.overrideWith(
          (ref) async => ModelTypeColors.fallback,
        ),
        todayLogsProvider.overrideWith((ref) async => []),
        dailyLogsForDayProvider.overrideWith((ref, day) async => []),
        tasksForTodayProvider.overrideWith((ref) => Completer<Never>().future),
        projectBreadcrumbLabelsProvider.overrideWith((ref) async => {}),
        allTasksProvider.overrideWith((ref) async => []),
        calendarRepositoryProvider.overrideWith(
          (ref) => Completer<Never>().future,
        ),
        calendarWeekProvider.overrideWith(
          (ref) => AsyncData(
            List.generate(
              7,
              (i) => CalendarDayData(
                day: ref.watch(currentWeekProvider).add(Duration(days: i)),
                rows: [],
              ),
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: TodayPage(snapshot: buildScreenshotTodaySnapshot()),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(
      tester.getBottomLeft(find.byType(TodayViewToggle)).dy,
      lessThan(tester.getTopLeft(find.byType(TimeMapBar)).dy),
    );
    expect(
      tester.getTopLeft(find.byType(ActionsPeriodToggle)).dx,
      lessThan(tester.getTopLeft(find.byType(TodayViewToggle)).dx),
    );

    for (final period in ActionsPeriod.values) {
      await tester.tap(
        find.text(period == ActionsPeriod.today ? 'Today' : 'History').last,
      );
      await tester.pump();
      for (final entry in {
        'Actions and logs': TodayViewMode.actions,
        'Stats': TodayViewMode.stats,
        'Tasks': TodayViewMode.tasks,
      }.entries) {
        await tester.tap(find.byTooltip(entry.key));
        await tester.pump();
        expect(container.read(todayViewModeProvider), entry.value);
        expect(container.read(actionsPeriodProvider), period);
        if (period == ActionsPeriod.history) {
          expect(
            tester.widget<HistoryPage>(find.byType(HistoryPage)).embeddedMode,
            entry.value,
          );
          expect(find.byType(BackButton), findsNothing);
          expect(find.byTooltip(entry.key), findsOneWidget);
        } else if (entry.value == TodayViewMode.tasks) {
          expect(
            tester.widget<TasksPage>(find.byType(TasksPage)).showHeader,
            isFalse,
          );
        }
        expect(
          tester.takeException(),
          isNull,
          reason: '$period ${entry.value}',
        );
      }
    }
    // Week navigation must not reset the externally selected Tasks mode.
    final previousWeek = container.read(currentWeekProvider);
    await tester.tap(find.byTooltip('Previous week'));
    await tester.pump();
    expect(
      container.read(currentWeekProvider),
      previousWeek.subtract(const Duration(days: 7)),
    );
    expect(container.read(todayViewModeProvider), TodayViewMode.tasks);
    expect(tester.takeException(), isNull);
  });
}
