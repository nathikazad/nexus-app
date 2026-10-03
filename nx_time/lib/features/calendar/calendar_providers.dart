import 'package:nx_time/data/domains/domain_workspace.dart';
import 'package:nx_time/features/calendar/calendar_feed_providers.dart';
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
final currentWeekProvider = NotifierProvider<CurrentWeek, DateTime>(
  CurrentWeek.new,
);

/// Monday 00:00 of the current calendar week (local) — the week the **Today** tab
/// shows. Evaluated on first read of this provider, not on every build; the week
/// does not auto-roll at midnight (same as before the week-store unification). Use
/// [invalidateActionsAfterMutation] after writes so the tab refetches.
final todayMondayProvider = Provider<DateTime>(
  (ref) => mondayOfWeek(DateTime.now()),
);

/// Loads every action for the week that starts on [monday] (one request), then
/// buckets by [actionOverlapsLocalCalendarDay] per day.
///
/// Colors are read at render time via [modelTypeColorsProvider], so this
/// provider intentionally does not await it (changing a color must not
/// trigger a re-fetch of the entire week's actions).
final weekActionsProvider = FutureProvider.autoDispose
    .family<WeekActions, DateTime>((ref, monday) async {
      await ref.watch(authenticatedUserProvider.future);
      final m0 = DateTime(monday.year, monday.month, monday.day);
      final repo = ref.watch(actionRepositoryProvider);
      final all = await repo.listForWeek(m0);
      final byDay = List.generate(7, (i) {
        final day = m0.add(Duration(days: i));
        return all
            .where((a) => actionOverlapsLocalCalendarDay(a, day))
            .toList();
      });
      return WeekActions(weekStart: m0, byDay: byDay, all: all);
    });

/// Action goals for the week starting on [monday] (`getActionGoalsWeek` — no expense
/// goals; action-only).
final actionGoalsWeekProvider = FutureProvider.autoDispose
    .family<ActionGoalsWeek, DateTime>((ref, monday) async {
      final m0 = DateTime(monday.year, monday.month, monday.day);
      final repo = ref.watch(goalRepositoryProvider);
      return repo.getActionGoalsWeek(weekStart: m0);
    });

/// Daily hit/total heatmap scores for the visible month on the Goals tab.
final actionGoalsMonthScoreProvider = FutureProvider.autoDispose
    .family<ActionGoalsMonthScore, DateTime>((ref, monthStart) async {
      final m0 = DateTime(monthStart.year, monthStart.month);
      final repo = ref.watch(goalRepositoryProvider);
      return repo.getActionGoalsMonthScore(monthStart: m0);
    });

/// After any local action create/update/delete, invalidates the week-action and
/// week-goal [FutureProvider] families. Refetches any **mounted** family instances
/// (e.g. Today's week, the calendar's selected week) — typically one or two weeks.
void invalidateActionsAfterMutation(WidgetRef ref) {
  ref.invalidate(calendarFeedProvider);
  ref.invalidate(calendarRefreshProvider);
  ref.invalidate(weekActionsProvider);
  ref.invalidate(domainWeekActionsProvider);
  ref.invalidate(goalWeekActionsProvider);
  ref.invalidate(actionGoalsWeekProvider);
  ref.invalidate(actionGoalsMonthScoreProvider);
}

/// Goal calculations use actions from the goal's own domain.
final goalWeekActionsProvider = FutureProvider.autoDispose
    .family<WeekActions, (int, DateTime)>((ref, key) async {
      final workspace = await ref.watch(timeDomainsProvider.future);
      final domain = await workspace.owner(key.$1);
      return ref.watch(domainWeekActionsProvider((domain, key.$2)).future);
    });
final domainWeekActionsProvider = FutureProvider.autoDispose
    .family<WeekActions, (int, DateTime)>((ref, key) async {
      final workspace = await ref.watch(timeDomainsProvider.future);
      final m = DateTime(key.$2.year, key.$2.month, key.$2.day);
      final all = await workspace.actions(key.$1).listForWeek(m);
      workspace.remember(key.$1, all.map((a) => a.id));
      return WeekActions(
        weekStart: m,
        all: all,
        byDay: List.generate(
          7,
          (i) => all
              .where(
                (a) =>
                    actionOverlapsLocalCalendarDay(a, m.add(Duration(days: i))),
              )
              .toList(),
        ),
      );
    });
