import 'package:nx_time/core/time/wall_clock_time.dart';
import 'package:nx_time/domain/goals/action_goal.dart';
import 'package:nx_time/domain/goals/goal_cadence.dart';
import 'package:nx_time/domain/goals/goal_day_state.dart';
import 'package:nx_time/domain/goals/goal_threshold.dart';

/// Monday 00:00:00 of the week containing [now] (local date).
DateTime mondayOfWeekStart(DateTime now) {
  final d = DateTime(now.year, now.month, now.day);
  return d.subtract(Duration(days: d.weekday - 1));
}

int dayKey(DateTime d) {
  final l = asStoredLocalWallClock(d);
  return l.year * 10000 + l.month * 100 + l.day;
}

/// Mon–Sun rows aligned to [weekStart] (date-only, Monday).
List<GoalDailyState> normalizeDailyStates(
  List<GoalDailyState> daily,
  DateTime weekStart,
) {
  final start = DateTime(weekStart.year, weekStart.month, weekStart.day);
  final byKey = <int, GoalDailyState>{};
  for (final s in daily) {
    byKey[dayKey(s.date)] = s;
  }
  return List.generate(7, (i) {
    final day = start.add(Duration(days: i));
    return byKey[dayKey(day)] ?? GoalDailyState(date: day, state: GoalDayState.pending);
  });
}

int countHits(List<GoalDailyState> daily) {
  return daily.where((d) => d.state == GoalDayState.hit).length;
}

DateTime get todayDate {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

bool isSameCalendarDate(DateTime a, DateTime b) {
  return dayKey(a) == dayKey(b);
}

int todayDowIndex0Mon() {
  // Monday = 0 … Sunday = 6
  return DateTime.now().weekday - 1;
}

/// From today through end of week (Sat/Sun as end): days including today.
int daysLeftInMonSunWeek() {
  return 7 - DateTime.now().weekday;
}

/// Converts `07:00:00` / `7:00:00` / `12:30` to a short 12h label (e.g. `7 AM`, `12:30 PM`).
String formatWallClock12h(String raw) {
  final t = raw.trim();
  if (t.isEmpty) {
    return raw;
  }
  final parts = t.split(':');
  if (parts.isEmpty) {
    return raw;
  }
  int h24;
  int min;
  try {
    h24 = int.parse(parts[0]);
    min = parts.length > 1 ? int.parse(parts[1]) : 0;
  } on FormatException {
    return raw;
  }
  h24 = h24 % 24;
  final isPm = h24 >= 12;
  var h12 = h24 % 12;
  if (h12 == 0) {
    h12 = 12;
  }
  final period = isPm ? 'PM' : 'AM';
  if (min == 0) {
    return '$h12 $period';
  }
  return '$h12:${min.toString().padLeft(2, '0')} $period';
}

bool _looksLikeWallTime(String s) {
  return RegExp(r'^\d{1,2}:\d{2}(:\d{2})?$').hasMatch(s.trim());
}

/// First filter `value` that looks like `HH:MM` / `HH:MM:SS`, formatted for display, or null.
String? thresholdWallClockFromFilter(ActionGoalWeekItem item) {
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
  if (v is! String || !_looksLikeWallTime(v)) {
    return null;
  }
  return formatWallClock12h(v);
}

/// Week hits, session target, and days left in the current Mon–Sun week (for weekly list rows).
({int hit, int total, int daysLeft}) weeklySlotCounts(
  ActionGoalWeekItem item,
  DateTime weekStart,
) {
  final days = normalizeDailyStates(item.dailyState, weekStart);
  final hit = countHits(days);
  final total = item.target.value.round();
  final daysLeft = daysLeftInMonSunWeek();
  return (hit: hit, total: total, daysLeft: daysLeft);
}

String formatGoalSubline(ActionGoalWeekItem item) {
  if (item.cadence == GoalCadence.daily) {
    final b = StringBuffer('Every day');
    b.write(' · ');
    if (item.filter != null) {
      final f = item.filter!;
      if (f['filters'] is List) {
        final list = f['filters'] as List<dynamic>;
        if (list.isNotEmpty && list.first is Map) {
          final m = Map<String, dynamic>.from(list.first as Map);
          final k = m['key'];
          final op = m['op'];
          final v = m['value'];
          b.write('$k $op $v');
          return b.toString();
        }
      }
    }
    if (item.metric == 'duration') {
      b.write(
        'sum ${metricLabel(item)} ${goalThresholdOpToKgql(item.target.op)} ${formatTargetValue(item)}',
      );
    } else {
      b.write(
        '${item.aggregation} ${item.selectedAttribute} ${goalThresholdOpToKgql(item.target.op)} ${formatTargetValue(item)}',
      );
    }
    return b.toString();
  }
  if (item.cadence == GoalCadence.weekly) {
    final b = StringBuffer('Every week');
    b.write(' · ');
    b.write(
      '${item.aggregation} ${item.metric != null ? metricLabel(item) : item.selectedAttribute} ${goalThresholdOpToKgql(item.target.op)} ${formatTargetValue(item)}',
    );
    return b.toString();
  }
  return '${item.cadence.name} · ${item.modelType}';
}

String metricLabel(ActionGoalWeekItem item) {
  if (item.metric == 'duration') {
    return 'duration';
  }
  return item.metric ?? 'value';
}

/// Human-readable [ActionGoalWeekItem.target] (e.g. `8h`, `3h`, `3`).
String formatTargetValue(ActionGoalWeekItem item) {
  if (item.metric == 'duration') {
    final s = item.target.value.round();
    if (s % 3600 == 0) {
      return '${s ~/ 3600}h';
    }
    if (s % 60 == 0) {
      return '${s ~/ 60}m';
    }
  }
  return item.target.value.toString();
}

List<(String, String)> howMeasuredRowsFor(ActionGoalWeekItem item) {
  final op = goalThresholdOpToKgql(item.target.op);
  final val = item.target.value;
  final hitLine = StringBuffer()
    ..write(item.aggregation)
    ..write(' ')
    ..write(item.metric != null ? metricLabel(item) : item.selectedAttribute)
    ..write(' ')
    ..write(op)
    ..write(' ')
    ..write(val);
  final rows = <(String, String)>[
    ('Tracks', item.modelType),
    ('Hits when', hitLine.toString()),
    ('Day attribution', item.selectedAttribute),
    ('Cadence', item.cadence.name),
  ];
  final slots = item.meta?.preferredSlots;
  if (slots != null && slots.isNotEmpty) {
    final joined = slots.map((s) => '${s.dow} ${s.startTime}').join(', ');
    rows.add(('Slot tasks', joined));
  }
  return rows;
}

String deleteBlurbForModel(String modelType) {
  switch (modelType) {
    case 'Gym':
      return 'Workouts stay; this goal stops tracking';
    case 'Sleep':
      return 'Sleep history stays; this goal stops tracking';
    case 'Yoga':
    case 'Reading':
    case 'Dance':
    case 'LanguageStudy':
      return 'History stays; this goal stops tracking';
    default:
      return 'History stays; this goal stops tracking';
  }
}

String editSubForModel(String modelType) {
  switch (modelType) {
    case 'Gym':
      return 'Change target, slots, or tag filter';
    default:
      return 'Change threshold time or filter';
  }
}

double trendBarHeight({required num successes, required num expected}) {
  if (expected == 0) {
    return 0;
  }
  return (successes / expected).clamp(0, 1).toDouble();
}

ActionGoalTrendBucket? latestBucket(List<ActionGoalTrendBucket> buckets) {
  if (buckets.isEmpty) {
    return null;
  }
  return buckets.last;
}

int trendWeeksHitCount(List<ActionGoalTrendBucket> buckets) {
  return buckets.where((b) => b.hit).length;
}
