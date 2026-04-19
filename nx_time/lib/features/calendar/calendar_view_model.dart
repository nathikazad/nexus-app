import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nx_time/data/providers.dart';
import 'package:nx_time/features/today/action_fold.dart';

/// One calendar day’s folded umbrella rows (after [listForCalendarDay]).
class CalendarDayData {
  const CalendarDayData({
    required this.day,
    required this.rows,
  });

  final DateTime day;
  final List<UmbrellaRow> rows;
}

/// Monday 00:00:00 of the week containing [weekAnyDay] (local).
DateTime mondayOfWeek(DateTime weekAnyDay) {
  final d = DateTime(weekAnyDay.year, weekAnyDay.month, weekAnyDay.day);
  return d.subtract(Duration(days: d.weekday - DateTime.monday));
}

/// Loads seven days starting Monday of the week containing [weekStartOrAny].
final calendarWeekProvider =
    FutureProvider.autoDispose.family<List<CalendarDayData>, DateTime>((ref, weekStartOrAny) async {
  final monday = mondayOfWeek(weekStartOrAny);
  final repo = ref.watch(actionRepositoryProvider);
  final out = <CalendarDayData>[];
  for (var i = 0; i < 7; i++) {
    final day = monday.add(Duration(days: i));
    final list = await repo.listForCalendarDay(day);
    out.add(CalendarDayData(day: day, rows: foldDayActions(list)));
  }
  return out;
});
