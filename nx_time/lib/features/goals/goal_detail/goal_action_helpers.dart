import 'package:nx_time/core/time/week_calendar.dart';
import 'package:nx_time/domain/action/action.dart';
import 'package:nx_time/domain/action/week_actions.dart';
import 'package:nx_time/domain/goals/action_goal.dart';
import 'package:nx_time/features/goals/goal_detail/goal_detail_helpers.dart';

/// Filters [wa.all] to actions for this goal’s model type.
///
/// **Limitation:** attribute filters in [item.filter] are not applied because
/// [Action] does not carry filter attribute payloads in the client.
List<Action> actionsForGoal(WeekActions wa, ActionGoalWeekItem item) {
  return wa.all.where((a) => a.modelTypeName == item.modelType).toList();
}

/// Calendar instant used for “which day” / display: prefers `end_time` when
/// [selectedAttribute] names end, otherwise start (then end).
DateTime? attributedDay(Action a, String selectedAttribute) {
  final lower = selectedAttribute.toLowerCase();
  if (lower == 'end_time' ||
      (lower.contains('end') && !lower.contains('start'))) {
    return a.endTime ?? a.startTime;
  }
  if (lower == 'start_time' || lower.contains('start')) {
    return a.startTime;
  }
  return a.endTime ?? a.startTime;
}

/// Groups [actions] into Mon=0 … Sun=6 by [attributedDay] falling on that
/// local calendar day within [wa.weekStart]’s week.
Map<int, List<Action>> bucketByDay(
  WeekActions wa,
  List<Action> actions,
  String selectedAttribute,
) {
  final m = <int, List<Action>>{for (var i = 0; i < 7; i++) i: []};
  final ws = DateTime(wa.weekStart.year, wa.weekStart.month, wa.weekStart.day);
  for (final a in actions) {
    final at = attributedDay(a, selectedAttribute);
    if (at == null) {
      continue;
    }
    final d = DateTime(at.year, at.month, at.day);
    final idx = d.difference(ws).inDays;
    if (idx >= 0 && idx < 7) {
      m[idx]!.add(a);
    }
  }
  for (final list in m.values) {
    list.sort((a, b) {
      final as = a.startTime ?? a.endTime;
      final bs = b.startTime ?? b.endTime;
      if (as == null && bs == null) {
        return a.id.compareTo(b.id);
      }
      if (as == null) {
        return 1;
      }
      if (bs == null) {
        return -1;
      }
      return as.compareTo(bs);
    });
  }
  return m;
}

/// Elapsed length of [a]; if open-ended, uses [cap] or [now] for the end.
Duration durationOf(Action a, {DateTime? cap, DateTime? now}) {
  final s = a.startTime;
  if (s == null) {
    return Duration.zero;
  }
  final n = now ?? DateTime.now();
  final e = a.endTime ?? cap ?? n;
  final d = e.difference(s);
  return d.isNegative ? Duration.zero : d;
}

/// Sums [durationOf] for [actions] attributed to [dayIndex0Mon], optionally
/// capping open intervals at "now" (for today / in-progress).
Duration sumDurationForDay(
  WeekActions wa,
  List<Action> actions,
  int dayIndex0Mon, {
  bool capAtNow = false,
  String selectedAttribute = 'end_time',
}) {
  if (dayIndex0Mon < 0 || dayIndex0Mon > 6) {
    return Duration.zero;
  }
  final dayDate = wa.weekStart.add(Duration(days: dayIndex0Mon));
  final d0 = DateTime(dayDate.year, dayDate.month, dayDate.day);
  var sum = Duration.zero;
  final now = DateTime.now();
  final capToday = capAtNow && isSameCalendarDate(d0, todayDate);
  for (final a in actions) {
    final at = attributedDay(a, selectedAttribute);
    if (at == null) {
      continue;
    }
    final ad = DateTime(at.year, at.month, at.day);
    if (ad != d0) {
      continue;
    }
    sum += durationOf(a, cap: capToday ? now : null, now: now);
  }
  return sum;
}

/// Total duration across the week (each action once).
Duration weekTotalDuration(List<Action> actions, {bool capAtNow = false}) {
  final now = DateTime.now();
  var sum = Duration.zero;
  for (final a in actions) {
    sum += durationOf(a, cap: capAtNow ? now : null, now: now);
  }
  return sum;
}

/// Today’s attributed sum for duration goals, or null when the viewed week is
/// not the current calendar week.
Duration? todaySoFarDuration(WeekActions wa, ActionGoalWeekItem item) {
  if (!isWeekCurrent(wa.weekStart)) {
    return null;
  }
  if (item.metric != 'duration') {
    return null;
  }
  final list = actionsForGoal(wa, item);
  final idx = todayDowIndex0Mon();
  if (idx < 0) {
    return null;
  }
  return sumDurationForDay(
    wa,
    list,
    idx,
    capAtNow: true,
    selectedAttribute: item.selectedAttribute,
  );
}

/// Latest attributed instant today for this goal, or null if none / not current week.
DateTime? todayAttributedTime(WeekActions wa, ActionGoalWeekItem item) {
  if (!isWeekCurrent(wa.weekStart)) {
    return null;
  }
  final list = actionsForGoal(wa, item);
  final buckets = bucketByDay(wa, list, item.selectedAttribute);
  final idx = todayDowIndex0Mon();
  final forDay = buckets[idx] ?? const <Action>[];
  if (forDay.isEmpty) {
    return null;
  }
  DateTime? best;
  for (final a in forDay) {
    final t = attributedDay(a, item.selectedAttribute);
    if (t == null) {
      continue;
    }
    if (best == null || t.isAfter(best)) {
      best = t;
    }
  }
  return best;
}

/// e.g. `8h 10m`, `45m`, or em dash for zero / invalid.
String formatDurationShort(Duration d, {bool useDashForZero = true}) {
  if (d == Duration.zero && useDashForZero) {
    return '—';
  }
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  if (h > 0) {
    if (m == 0) {
      return '${h}h';
    }
    return '${h}h ${m}m';
  }
  return '${d.inMinutes}m';
}

/// 12h clock without period, e.g. `6:48`, `12:30`.
String formatHoursMinutes12h(DateTime dt) {
  var h = dt.hour % 12;
  if (h == 0) {
    h = 12;
  }
  final mm = dt.minute.toString().padLeft(2, '0');
  return '$h:$mm';
}

/// `AM` or `PM` for [dt] in local time.
String formatAmPm(DateTime dt) => dt.hour < 12 ? 'AM' : 'PM';

/// Minutes 0–1439 from first wall-clock filter in [item], or null.
int? thresholdClockMinutes24(ActionGoalWeekItem item) {
  final f = item.filter;
  if (f == null) {
    return null;
  }
  if (f['filters'] is! List) {
    return null;
  }
  final list = f['filters'] as List<dynamic>;
  if (list.isEmpty || list.first is! Map) {
    return null;
  }
  final m = Map<String, dynamic>.from(list.first as Map);
  final v = m['value'];
  if (v is! String) {
    return null;
  }
  final t = v.trim();
  if (!RegExp(r'^\d{1,2}:\d{2}(:\d{2})?$').hasMatch(t)) {
    return null;
  }
  final parts = t.split(':');
  final h = int.parse(parts[0]) % 24;
  final min = parts.length > 1 ? int.parse(parts[1]) : 0;
  return h * 60 + min;
}

/// Position on the 5–8 AM track: `(todMinutes - 300) / 180`, in \[0,1\].
double wakeTrackPositionFromTime(DateTime t) {
  final minutes = t.hour * 60 + t.minute;
  const start = 5 * 60; // 5 * 60 = 300
  const end = 8 * 60; // 480
  if (minutes <= start) {
    return 0;
  }
  if (minutes >= end) {
    return 1;
  }
  return (minutes - start) / (end - start);
}

/// Horizontal position of the goal threshold on the 5–8 AM track, or null.
double? thresholdTrackPosition(ActionGoalWeekItem item) {
  final m = thresholdClockMinutes24(item);
  if (m == null) {
    return null;
  }
  return wakeTrackPositionFromTime(DateTime(2000, 1, 1, m ~/ 60, m % 60));
}

int _clockMinutes(DateTime t) => t.hour * 60 + t.minute;

/// Subtitle under wake hero: “N min before goal”, “N min after goal”, or
/// `null` to show “no data” / non-comparable.
String? wakeDeltaVsThresholdLine(ActionGoalWeekItem item, DateTime? wake) {
  if (wake == null) {
    return null;
  }
  final th = thresholdClockMinutes24(item);
  if (th == null) {
    return null;
  }
  final w = _clockMinutes(wake);
  final diff = th - w;
  if (diff == 0) {
    return 'on goal';
  }
  if (diff > 0) {
    return '$diff min before goal';
  }
  return '${-diff} min after goal';
}

/// True if [wake] is on or before the goal wall-clock.
bool wakeIsOnTrack(ActionGoalWeekItem item, DateTime? wake) {
  if (wake == null) {
    return false;
  }
  final th = thresholdClockMinutes24(item);
  if (th == null) {
    return true;
  }
  return _clockMinutes(wake) <= th;
}

/// Days from today through Sunday for the “days left in week” copy. Past
/// week → 0; future week → 7; current Mon–Sun week → [daysLeftInMonSunWeek].
int daysLeftInSelectedWeek(WeekActions wa) {
  final now = DateTime.now();
  final today0 = DateTime(now.year, now.month, now.day);
  final ws = DateTime(wa.weekStart.year, wa.weekStart.month, wa.weekStart.day);
  final weekEnd = ws.add(const Duration(days: 6));
  if (weekEnd.isBefore(today0)) {
    return 0;
  }
  if (ws.isAfter(today0)) {
    return 7;
  }
  return daysLeftInMonSunWeek();
}

/// Last wake (or attributed) time on that day in the week, or null.
DateTime? attributedTimeOnDay(
  WeekActions wa,
  ActionGoalWeekItem item,
  int dayIndex0Mon,
) {
  final list = actionsForGoal(wa, item);
  final buckets = bucketByDay(wa, list, item.selectedAttribute);
  final forDay = buckets[dayIndex0Mon] ?? const <Action>[];
  if (forDay.isEmpty) {
    return null;
  }
  DateTime? best;
  for (final a in forDay) {
    final t = attributedDay(a, item.selectedAttribute);
    if (t == null) {
      continue;
    }
    if (best == null || t.isAfter(best)) {
      best = t;
    }
  }
  return best;
}
