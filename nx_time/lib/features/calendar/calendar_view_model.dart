import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nx_time/features/calendar/calendar_providers.dart';
import 'package:nx_time/features/today/action_fold.dart';

/// One calendar day’s folded umbrella rows (after [weekActionsProvider] + [foldDayActions]).
class CalendarDayData {
  const CalendarDayData({
    required this.day,
    required this.rows,
  });

  final DateTime day;
  final List<UmbrellaRow> rows;
}

/// Seven days (Mon–Sun) derived from the shared [weekActionsProvider] store.
final calendarWeekProvider = Provider<AsyncValue<List<CalendarDayData>>>((ref) {
  return ref.watch(weekActionsProvider).when(
        data: (wa) {
          return AsyncValue.data(
            List.generate(
              7,
              (i) => CalendarDayData(
                day: wa.weekStart.add(Duration(days: i)),
                rows: foldDayActions(wa.byDay[i]),
              ),
            ),
          );
        },
        loading: () => const AsyncValue<List<CalendarDayData>>.loading(),
        error: (e, st) => AsyncValue<List<CalendarDayData>>.error(e, st),
      );
});
