import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nx_time/data/providers.dart';
import 'package:nx_time/domain/log/daily_log.dart';

/// Today tab view mode — toggles between the activity timeline and stats list.
enum TodayViewMode { actions, stats, tasks }

class TodayViewModeNotifier extends Notifier<TodayViewMode> {
  @override
  TodayViewMode build() => TodayViewMode.actions;

  void set(TodayViewMode mode) => state = mode;
}

final todayViewModeProvider =
    NotifierProvider<TodayViewModeNotifier, TodayViewMode>(
      TodayViewModeNotifier.new,
    );

enum ActionsPeriod { today, history }

class ActionsPeriodNotifier extends Notifier<ActionsPeriod> {
  @override
  ActionsPeriod build() => ActionsPeriod.today;

  void set(ActionsPeriod period) => state = period;
}

final actionsPeriodProvider =
    NotifierProvider<ActionsPeriodNotifier, ActionsPeriod>(
      ActionsPeriodNotifier.new,
    );

/// Daily Log rows whose `logged_at` falls in today's local calendar day.
///
/// Uses the same wall-clock day as the Today actions view ([DateTime.now]).
/// Refetched after any log mutation via [invalidateLogsAfterMutation].
final todayLogsProvider = FutureProvider.autoDispose<List<DailyLog>>((
  ref,
) async {
  final repo = ref.watch(logRepositoryProvider);
  return repo.listForCalendarDay(DateTime.now());
});

/// Daily Log rows whose `logged_at` falls in [dayLocal]'s local calendar day.
final dailyLogsForDayProvider = FutureProvider.autoDispose
    .family<List<DailyLog>, DateTime>((ref, dayLocal) async {
      final repo = ref.watch(logRepositoryProvider);
      return repo.listForCalendarDay(dayLocal);
    });

void invalidateLogsAfterMutation(WidgetRef ref) {
  ref.invalidate(todayLogsProvider);
  ref.invalidate(dailyLogsForDayProvider);
}
