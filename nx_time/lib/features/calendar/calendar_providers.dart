import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nx_time/core/time/action_calendar_overlap.dart';
import 'package:nx_time/core/time/week_calendar.dart';
import 'package:nx_time/data/providers.dart';
import 'package:nx_time/domain/action/week_actions.dart';
import 'package:nx_time/domain/goals/action_goal.dart';

/// The Monday (date at 00:00) of the week shown in calendar + goals.
class CurrentWeek extends Notifier<DateTime> {
  @override
  DateTime build() => mondayOfWeek(DateTime.now());

  /// Move the visible week; [monday] is normalized to local date at 00:00.
  void setLocalWeekMonday(DateTime monday) {
    state = DateTime(monday.year, monday.month, monday.day);
  }
}

/// Notifier: `ref.read(currentWeekProvider.notifier).state = monday` to change week.
final currentWeekProvider =
    NotifierProvider<CurrentWeek, DateTime>(CurrentWeek.new);

/// Loads every action for [currentWeekProvider] in one request, then buckets by
/// [actionOverlapsLocalCalendarDay] per day.
final weekActionsProvider =
    FutureProvider.autoDispose<WeekActions>((ref) async {
  await ref.watch(authenticatedUserProvider.future);
  final monday = ref.watch(currentWeekProvider);
  final m0 = DateTime(monday.year, monday.month, monday.day);
  final repo = ref.watch(actionRepositoryProvider);
  final all = await repo.listForWeek(m0);
  final byDay = List.generate(7, (i) {
    final day = m0.add(Duration(days: i));
    return all.where((a) => actionOverlapsLocalCalendarDay(a, day)).toList();
  });
  return WeekActions(weekStart: m0, byDay: byDay, all: all);
});

/// Current week's action goals (no expense goals — `getActionGoalsWeek` is action-only).
final actionGoalsWeekProvider = FutureProvider<ActionGoalsWeek>((ref) async {
  final monday = ref.watch(currentWeekProvider);
  final repo = ref.watch(goalRepositoryProvider);
  return repo.getActionGoalsWeek(weekStart: monday);
});

/// Call after an action is created/updated/deleted on a day so calendar + goals refetch.
void invalidateWeekActions(WidgetRef ref) {
  ref.invalidate(weekActionsProvider);
  ref.invalidate(actionGoalsWeekProvider);
}
