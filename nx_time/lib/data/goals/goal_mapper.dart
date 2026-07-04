import 'package:nx_db/goals.dart' as nx;
import 'package:nx_db/kgql.dart';
import 'package:nx_time/core/time/wall_clock_time.dart';
import 'package:nx_time/data/goals/goal_attr_keys.dart';
import 'package:nx_time/domain/goals/action_goal.dart';
import 'package:nx_time/domain/goals/expense_goal.dart';
import 'package:nx_time/domain/goals/goal.dart';
import 'package:nx_time/domain/goals/goal_cadence.dart';
import 'package:nx_time/domain/goals/goal_day_state.dart';
import 'package:nx_time/domain/goals/goal_preferred_slot.dart';
import 'package:nx_time/domain/goals/goal_selected_attribute.dart';
import 'package:nx_time/domain/goals/goal_streak.dart';
import 'package:nx_time/domain/goals/goal_threshold.dart';

GoalTarget _targetFromWire(nx.GoalTarget t) {
  return GoalTarget(op: goalThresholdOpFromKgql(t.op), value: t.value);
}

GoalStreakWindow _streakWindowFromWire(nx.GoalStreakWindow w) {
  return GoalStreakWindow(
    streakCount: w.streakCount,
    firstPeriod: w.firstPeriod == null
        ? null
        : asStoredLocalWallClock(w.firstPeriod!),
    lastPeriod: w.lastPeriod == null
        ? null
        : asStoredLocalWallClock(w.lastPeriod!),
  );
}

GoalStreakSummary _streakFromWire(nx.GoalStreakSummary s) {
  return GoalStreakSummary(
    isActive: s.isActive,
    currentPeriodHit: s.currentPeriodHit,
    current: _streakWindowFromWire(s.current),
    max: _streakWindowFromWire(s.max),
  );
}

GoalDayState _dayStateFromWire(nx.GoalDayState s) {
  switch (s) {
    case nx.GoalDayState.hit:
      return GoalDayState.hit;
    case nx.GoalDayState.miss:
      return GoalDayState.miss;
    case nx.GoalDayState.pending:
      return GoalDayState.pending;
  }
}

ActionGoalMeta? _metaFromWire(nx.ActionGoalMeta? m) {
  if (m == null) return null;
  return ActionGoalMeta(
    preferredSlots: m.preferredSlots
        ?.map(
          (s) => GoalPreferredSlot(
            dow: s.dow,
            startTime: s.startTime,
            durationMin: s.durationMin,
            hit: s.hit,
          ),
        )
        .toList(),
    autoGenerateTasks: m.autoGenerateTasks,
  );
}

ActionGoalWeekItem _weekItemFromWire(nx.ActionGoalWeekItem w) {
  return ActionGoalWeekItem(
    id: w.id,
    label: w.label,
    cadence: goalCadenceFromKgql(w.cadence),
    modelType: w.modelType,
    filter: w.filter,
    selectedAttribute: w.selectedAttribute,
    aggregation: w.aggregation,
    metric: w.metric,
    target: _targetFromWire(w.target),
    dailyState: w.dailyState
        .map(
          (d) => GoalDailyState(
            date: asStoredLocalWallClock(d.date),
            state: _dayStateFromWire(d.state),
          ),
        )
        .toList(),
    streak: _streakFromWire(w.streak),
    meta: _metaFromWire(w.meta),
  );
}

ActionGoalsWeek actionGoalsWeekFromWire(nx.ActionGoalWeekResponse w) {
  return ActionGoalsWeek(
    weekStart: asStoredLocalWallClock(w.weekStart),
    items: w.items.map(_weekItemFromWire).toList(),
  );
}

ActionGoalsMonth actionGoalsMonthFromWire(nx.ActionGoalMonthResponse w) {
  return ActionGoalsMonth(
    monthStart: asStoredLocalWallClock(w.monthStart),
    items: w.items.map(_weekItemFromWire).toList(),
  );
}

/// When PostGraphile returns the partial `{ "buckets": [] }` shape (goal missing).
ActionGoalsTrend actionGoalsTrendFromWire(
  nx.ActionGoalTrendResponse w, {
  required int requestedGoalId,
  required int requestedWeeks,
}) {
  if (w.goalId == null && w.cadence == null && w.weeks == null) {
    return ActionGoalsTrend.emptyEnvelope(
      requestedGoalId: requestedGoalId,
      requestedWeeks: requestedWeeks,
    );
  }
  return ActionGoalsTrend(
    goalId: w.goalId,
    cadence: w.cadence == null ? null : goalCadenceFromKgql(w.cadence!),
    weeks: w.weeks,
    buckets: w.buckets
        .map(
          (b) => ActionGoalTrendBucket(
            periodStart: asStoredLocalWallClock(b.periodStart),
            successes: b.successes,
            expected: b.expected,
            hit: b.hit,
          ),
        )
        .toList(),
  );
}

ExpenseGoalMonthItem _expenseItemFromWire(nx.ExpenseGoalMonthItem w) {
  return ExpenseGoalMonthItem(
    id: w.id,
    label: w.label,
    cadence: goalCadenceFromKgql(w.cadence),
    modelType: w.modelType,
    filter: w.filter,
    selectedAttribute: w.selectedAttribute,
    aggregation: w.aggregation,
    metric: w.metric,
    target: _targetFromWire(w.target),
    periodValue: w.periodValue,
  );
}

ExpenseGoalsMonth expenseGoalsMonthFromWire(nx.ExpenseGoalMonthResponse w) {
  return ExpenseGoalsMonth(
    monthStart: asStoredLocalWallClock(w.monthStart),
    items: w.items.map(_expenseItemFromWire).toList(),
  );
}

// -----------------------------------------------------------------------------
// Editable [Goal] ⇄ `Model` / `set_kgql_models` (see demo seed goals).

const List<String> _kDowNames = <String>[
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

int? _dowIndexFromName(String? s) {
  if (s == null) return null;
  var i = _kDowNames.indexOf(s);
  if (i >= 0) return i;
  i = int.tryParse(s) ?? -1;
  if (i >= 0 && i <= 6) return i;
  return null;
}

String _dowNameFromIndex(int i) {
  if (i < 0 || i > 6) {
    return _kDowNames[0];
  }
  return _kDowNames[i % 7];
}

dynamic _attr(Model m, String key) {
  return m.attributes?[key];
}

num? _readNum(dynamic v) {
  if (v is num) return v;
  return null;
}

int _minutesFromHhmmss(String raw) {
  final s = raw.trim();
  final parts = s.split(':');
  if (parts.isEmpty) return 0;
  final h = int.tryParse(parts[0].trim()) ?? 0;
  final m = parts.length > 1 ? (int.tryParse(parts[1].trim()) ?? 0) : 0;
  return h * 60 + m;
}

String _hhmmssFromMinutes(int m) {
  var x = m;
  if (x < 0) x = 0;
  if (x > 24 * 60) x = 24 * 60;
  final h = x ~/ 60;
  final min = x % 60;
  return '${h.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}:00';
}

GoalThresholdOp _opFromFilter(String? filterOp) {
  switch (filterOp) {
    case '<':
      return GoalThresholdOp.lt;
    case '<=':
      return GoalThresholdOp.lte;
    case '>':
      return GoalThresholdOp.gt;
    case '>=':
      return GoalThresholdOp.gte;
    case '==':
      return GoalThresholdOp.eq;
    default:
      return GoalThresholdOp.gte;
  }
}

String _filterOpForTime(GoalThresholdOp op) {
  switch (op) {
    case GoalThresholdOp.lt:
    case GoalThresholdOp.lte:
      return '<=';
    case GoalThresholdOp.gt:
    case GoalThresholdOp.gte:
      return '>=';
    case GoalThresholdOp.eq:
      return '==';
  }
}

Map<String, dynamic> _timeFilter(
  GoalSelectedAttribute t,
  GoalThresholdOp op,
  int minutes,
) {
  final col = t == GoalSelectedAttribute.startTime ? 'start_time' : 'end_time';
  return {
    'filters': <Map<String, String>>[
      {
        'key': col,
        'op': _filterOpForTime(op),
        'value': _hhmmssFromMinutes(minutes),
      },
    ],
  };
}

class _KBundle {
  const _KBundle({required this.selectedK, this.aggregation, this.metric});

  final String selectedK;
  final String? aggregation;
  final String? metric;
}

_KBundle _encodeBundle(Goal g) {
  switch (g.selectedAttribute) {
    case GoalSelectedAttribute.count:
      return const _KBundle(
        selectedK: 'start_time',
        aggregation: 'count',
        metric: null,
      );
    case GoalSelectedAttribute.duration:
      final isSleep = g.actionModelTypeName == 'Sleep';
      return _KBundle(
        selectedK: isSleep ? 'end_time' : 'start_time',
        aggregation: 'sum',
        metric: 'duration',
      );
    case GoalSelectedAttribute.startTime:
      return const _KBundle(
        selectedK: 'start_time',
        aggregation: 'count',
        metric: null,
      );
    case GoalSelectedAttribute.endTime:
      return const _KBundle(
        selectedK: 'end_time',
        aggregation: 'count',
        metric: null,
      );
  }
}

Map<String, dynamic>? _buildMeta(Goal g) {
  if (g.cadence != GoalCadence.weekly ||
      g.selectedAttribute != GoalSelectedAttribute.count) {
    return null;
  }
  final slots = <Map<String, dynamic>>[];
  for (final d in g.preferredDays) {
    slots.add({
      'dow': _dowNameFromIndex(d),
      'start_time': g.preferredTime ?? '',
      'duration_min': 0,
    });
  }
  return {'preferred_slots': slots, 'auto_generate_tasks': g.autoGenerateTasks};
}

List<SetModelAttribute> _goalToAttributes(Goal g) {
  final b = _encodeBundle(g);
  final nFilter =
      g.filter ??
      (g.selectedAttribute == GoalSelectedAttribute.startTime ||
              g.selectedAttribute == GoalSelectedAttribute.endTime
          ? _timeFilter(g.selectedAttribute, g.op, g.thresholdValue.round())
          : null);
  var thresholdNum = g.thresholdValue;
  if (g.selectedAttribute == GoalSelectedAttribute.duration) {
    thresholdNum = (g.thresholdValue * 3600.0).round();
  } else if (g.selectedAttribute == GoalSelectedAttribute.startTime ||
      g.selectedAttribute == GoalSelectedAttribute.endTime) {
    thresholdNum = 1;
  } else if (g.selectedAttribute == GoalSelectedAttribute.count) {
    thresholdNum = g.thresholdValue.round();
  }
  final meta = _buildMeta(g);
  return [
    SetModelAttribute(key: kGoalAttrLabel, value: g.label),
    SetModelAttribute(key: kGoalAttrActive, value: g.active),
    SetModelAttribute(
      key: kGoalAttrCadence,
      value: goalCadenceToKgql(g.cadence),
    ),
    SetModelAttribute(key: kGoalAttrModelType, value: g.actionModelTypeName),
    SetModelAttribute(key: kGoalAttrFilter, value: nFilter),
    SetModelAttribute(key: kGoalAttrSelectedAttribute, value: b.selectedK),
    SetModelAttribute(
      key: kGoalAttrAggregation,
      value: b.aggregation ?? 'count',
    ),
    SetModelAttribute(key: kGoalAttrMetric, value: b.metric),
    SetModelAttribute(
      key: kGoalAttrThresholdOp,
      value: goalThresholdOpToKgql(
        g.selectedAttribute == GoalSelectedAttribute.startTime ||
                g.selectedAttribute == GoalSelectedAttribute.endTime
            ? GoalThresholdOp.gte
            : g.op,
      ),
    ),
    SetModelAttribute(key: kGoalAttrThresholdValue, value: thresholdNum),
    if (meta != null) SetModelAttribute(key: kGoalAttrMeta, value: meta),
  ];
}

Map<String, dynamic>? _firstTimeFilterMap(Map<String, dynamic>? filter) {
  if (filter == null) return null;
  final list = filter['filters'];
  if (list is! List || list.isEmpty) return null;
  final f = list[0];
  if (f is! Map) return null;
  return Map<String, dynamic>.from(f);
}

/// Reads a stored `Goal` model into the editable [Goal] for the form.
Goal goalFromModel(Model m) {
  var label = m.name.trim().isNotEmpty
      ? m.name
      : (_attr(m, kGoalAttrLabel) as String? ?? '');
  if (label.isEmpty) {
    label = '';
  }
  final activeRaw = _attr(m, kGoalAttrActive);
  final active = activeRaw is bool
      ? activeRaw
      : (activeRaw ?? true) as bool? ?? true;
  final cadenceRaw = _attr(m, kGoalAttrCadence) as String? ?? 'daily';
  final cadence = goalCadenceFromKgql(cadenceRaw);
  final modelType = _attr(m, kGoalAttrModelType) as String? ?? 'Sleep';
  final rawFilter = _attr(m, kGoalAttrFilter);
  Map<String, dynamic>? filter;
  if (rawFilter is Map) {
    filter = Map<String, dynamic>.from(rawFilter);
  }
  final ag = _attr(m, kGoalAttrAggregation) as String? ?? 'count';
  final metric = _attr(m, kGoalAttrMetric) as String?;
  final tOp = goalThresholdOpFromKgql(
    _attr(m, kGoalAttrThresholdOp) as String? ?? '>=',
  );
  final tVal = _readNum(_attr(m, kGoalAttrThresholdValue)) ?? 0;
  final rawMeta = _attr(m, kGoalAttrMeta);
  Map<String, dynamic>? meta;
  if (rawMeta is Map<String, dynamic>) {
    meta = rawMeta;
  } else if (rawMeta is Map) {
    meta = Map<String, dynamic>.from(rawMeta);
  }

  final firstF = _firstTimeFilterMap(filter);
  final hasTimeFilter =
      firstF != null &&
      ((firstF['key'] as String?) == 'start_time' ||
          (firstF['key'] as String?) == 'end_time');

  GoalSelectedAttribute sel;
  num threshold;
  GoalThresholdOp domainOp = tOp;

  if (ag == 'sum' && metric == 'duration') {
    sel = GoalSelectedAttribute.duration;
    threshold = tVal / 3600.0;
  } else if (ag == 'count' && hasTimeFilter) {
    final k = firstF['key'] as String? ?? 'end_time';
    sel = k == 'start_time'
        ? GoalSelectedAttribute.startTime
        : GoalSelectedAttribute.endTime;
    final val = firstF['value'] as String? ?? '00:00:00';
    threshold = _minutesFromHhmmss(val);
    domainOp = _opFromFilter(firstF['op'] as String?);
  } else if (ag == 'count' && tVal > 0 && (metric == null)) {
    // Session count: gym, yoga, … (no time filter, no sum metric)
    sel = GoalSelectedAttribute.count;
    threshold = tVal;
  } else {
    // Fallback: treat as count
    sel = GoalSelectedAttribute.count;
    threshold = tVal;
  }

  var preferredDays = <int>[];
  String? preferredTime;
  var auto = false;
  if (meta != null) {
    auto = meta['auto_generate_tasks'] as bool? ?? false;
    final ps = meta['preferred_slots'] as List<dynamic>?;
    if (ps != null) {
      final tSet = <String>{};
      for (final s in ps) {
        if (s is! Map) continue;
        final m2 = Map<String, dynamic>.from(s);
        final i = _dowIndexFromName(m2['dow']?.toString());
        if (i != null) {
          preferredDays.add(i);
        }
        final st = m2['start_time'] as String?;
        if (st != null && st.isNotEmpty) {
          tSet.add(st);
        }
      }
      preferredDays = preferredDays..sort();
      if (tSet.length == 1) {
        preferredTime = tSet.first;
      }
    }
  }

  return Goal(
    id: m.id,
    label: label,
    active: active,
    cadence: cadence,
    actionModelTypeName: modelType,
    selectedAttribute: sel,
    op:
        (sel == GoalSelectedAttribute.startTime ||
            sel == GoalSelectedAttribute.endTime)
        ? domainOp
        : tOp,
    thresholdValue: threshold,
    filter:
        (sel == GoalSelectedAttribute.startTime ||
            sel == GoalSelectedAttribute.endTime)
        ? null
        : filter,
    preferredDays: preferredDays,
    preferredTime: preferredTime,
    autoGenerateTasks: auto,
  );
}

SetModelRequest setModelRequestForCreateGoal(Goal g) {
  return setKgqlCreate(
    modelType: kGoalModelTypeName,
    name: g.label,
    description: null,
    attributes: _goalToAttributes(g),
  );
}

SetModelRequest setModelRequestForUpdateGoal(Goal g) {
  if (g.id == null) {
    throw StateError('update requires id');
  }
  return setKgqlUpdate(
    id: g.id!,
    modelType: kGoalModelTypeName,
    name: g.label,
    description: null,
    attributes: _goalToAttributes(g),
  );
}

SetModelRequest setModelRequestForDeleteGoal(int id) => setKgqlDelete(id);
