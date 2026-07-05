import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icon_pack/solar_icon_pack.dart';

import 'package:nx_time/core/theme/app_theme.dart';
import 'package:nx_time/core/time/wall_clock_time.dart';
import 'package:nx_time/core/time/week_calendar.dart';
import 'package:nx_time/core/widgets/nx_tab_header.dart';
import 'package:nx_time/domain/action/week_actions.dart';
import 'package:nx_time/domain/goals/action_goal.dart';
import 'package:nx_time/domain/goals/goal_cadence.dart';
import 'package:nx_time/domain/goals/goal_day_state.dart';
import 'package:nx_time/features/calendar/calendar_providers.dart';
import 'package:nx_time/features/goals/goal_detail/goal_action_helpers.dart';
import 'package:nx_time/features/goals/goal_detail/goal_detail_helpers.dart';
import 'package:nx_time/features/goals/goal_detail/goal_detail_page.dart';
import 'package:nx_time/features/goals/goal_edit/goal_edit_page.dart';
import 'package:nx_time/features/goals/goal_edit/goal_edit_view_model.dart';
import 'package:nx_time/features/today/day_actions_page.dart';

class GoalsPage extends ConsumerStatefulWidget {
  const GoalsPage({super.key});

  static void openDetail(BuildContext context, int goalId) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => GoalDetailPage(goalId: goalId)),
    );
  }

  static void openCreate(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const GoalEditPage(mode: GoalEditMode.create),
      ),
    );
  }

  @override
  ConsumerState<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends ConsumerState<GoalsPage> {
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    _visibleMonth = monthStartOf(DateTime.now());
  }

  void _changeMonth(int delta) {
    setState(() {
      _visibleMonth = addCalendarMonths(_visibleMonth, delta);
    });
  }

  void _changeWeek(DateTime monday, int delta) {
    final m0 = DateTime(monday.year, monday.month, monday.day);
    ref
        .read(currentWeekProvider.notifier)
        .setLocalWeekMonday(m0.add(Duration(days: 7 * delta)));
  }

  void _openDay(DateTime day) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => DayActionsPage(date: day)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = ref.watch(currentWeekProvider);
    final monday = DateTime(m.year, m.month, m.day);
    final weekAsync = ref.watch(actionGoalsWeekProvider(monday));
    final weekActions = ref.watch(weekActionsProvider(monday));
    final monthScore = ref.watch(actionGoalsMonthScoreProvider(_visibleMonth));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const NxTabHeader(title: 'Goals'),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
            children: [
              _GoalsMonthHeatmap(
                visibleMonth: _visibleMonth,
                score: monthScore,
                onPreviousMonth: () => _changeMonth(-1),
                onNextMonth: () => _changeMonth(1),
                onDayTap: _openDay,
              ),
              const SizedBox(height: 22),
              _GoalsWeekNavigator(
                weekStart: monday,
                onPreviousWeek: () => _changeWeek(monday, -1),
                onNextWeek: () => _changeWeek(monday, 1),
              ),
              const SizedBox(height: 12),
              ...weekAsync.when<List<Widget>>(
                data: (week) {
                  final ws = asStoredLocalWallClock(week.weekStart);
                  final daily = week.items
                      .where((e) => e.cadence == GoalCadence.daily)
                      .toList();
                  final weekly = week.items
                      .where((e) => e.cadence == GoalCadence.weekly)
                      .toList();
                  final wa = weekActions.maybeWhen(
                    data: (d) => d,
                    orElse: () => null,
                  );
                  return [
                    const _SectionLabel(text: 'Daily goals'),
                    ...daily.map(
                      (item) => _buildDailyRow(context, item, ws, wa),
                    ),
                    const SizedBox(height: 14),
                    const _SectionLabel(text: 'Weekly goals'),
                    ...weekly.map(
                      (item) => _buildWeeklyRow(context, item, ws, wa),
                    ),
                    _AddGoalRow(onTap: () => GoalsPage.openCreate(context)),
                  ];
                },
                loading: () => const [
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 36),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ],
                error: (e, _) => [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'Could not load goals: $e',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.slate500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

GoalDailyState? _todayInWeek(ActionGoalWeekItem item, DateTime weekStart) {
  final days = normalizeDailyStates(item.dailyState, weekStart);
  final i = todayDowIndex0Mon();
  if (i < 0 || i >= days.length) {
    return null;
  }
  return days[i];
}

String _rightStatusText(
  ActionGoalWeekItem item,
  DateTime weekStart,
  WeekActions? wa,
) {
  final today = _todayInWeek(item, weekStart);
  if (today?.state == GoalDayState.notDue) {
    return 'not due';
  }
  if (item.cadence == GoalCadence.weekly) {
    if (item.aggregation == 'count') {
      final days = normalizeDailyStates(item.dailyState, weekStart);
      final hits = countHits(days);
      return '$hits of ${item.target.value}';
    }
    if (item.aggregation == 'sum' && item.metric == 'duration' && wa != null) {
      final list = actionsForGoal(wa, item);
      final wk = weekTotalDuration(list, capAtNow: isWeekCurrent(wa.weekStart));
      return formatDurationShort(wk, useDashForZero: false);
    }
    if (item.aggregation == 'sum' && item.metric == 'duration') {
      return '${formatTargetValue(item)} target';
    }
    return '—';
  }

  if (wa != null && isWeekCurrent(wa.weekStart)) {
    if (item.cadence == GoalCadence.daily &&
        item.aggregation == 'sum' &&
        item.metric == 'duration') {
      final d = todaySoFarDuration(wa, item);
      if (d != null) {
        return '${formatDurationShort(d, useDashForZero: false)} today';
      }
    }
    if (item.cadence == GoalCadence.daily &&
        item.aggregation == 'count' &&
        item.modelType == 'Sleep') {
      var t = todayAttributedTime(wa, item);
      var fromYesterday = false;
      if (t == null) {
        final idx = todayDowIndex0Mon();
        if (item.selectedAttribute.toLowerCase().contains('start') && idx > 0) {
          t = attributedTimeOnDay(wa, item, idx - 1);
          fromYesterday = t != null;
        }
      }
      if (t != null) {
        return '${formatHoursMinutes12h(t)} ${fromYesterday ? 'last night' : 'today'}';
      }
    }
    if (item.cadence == GoalCadence.daily &&
        item.aggregation == 'count' &&
        item.modelType != 'Sleep') {
      final list = actionsForGoal(wa, item);
      final idx = todayDowIndex0Mon();
      final dur = sumDurationForDay(
        wa,
        list,
        idx,
        capAtNow: true,
        selectedAttribute: item.selectedAttribute,
      );
      if (dur > Duration.zero) {
        return '${formatDurationShort(dur, useDashForZero: false)} today';
      }
    }
  }

  final t = _todayInWeek(item, weekStart);
  if (t == null) {
    return '—';
  }
  return switch (t.state) {
    GoalDayState.hit => 'on track',
    GoalDayState.miss => 'missed',
    GoalDayState.pending => 'pending',
    GoalDayState.notDue => 'not due',
  };
}

Color _rightStatusColor(
  ActionGoalWeekItem item,
  DateTime weekStart,
  WeekActions? wa,
) {
  if (item.cadence == GoalCadence.weekly) {
    if (item.streak.currentPeriodHit) {
      return AppColors.goalOnTrack;
    }
    if (daysLeftInMonSunWeek() == 0 && !item.streak.currentPeriodHit) {
      return AppColors.goalMissed;
    }
    return AppColors.goalAtRisk;
  }

  if (wa != null && isWeekCurrent(wa.weekStart)) {
    if (item.cadence == GoalCadence.daily &&
        item.aggregation == 'sum' &&
        item.metric == 'duration') {
      final d = todaySoFarDuration(wa, item);
      if (d != null) {
        if (d.inSeconds >= item.target.value) {
          return AppColors.goalOnTrack;
        }
        return _colorForDayState(_todayInWeek(item, weekStart));
      }
    }
    if (item.cadence == GoalCadence.daily &&
        item.aggregation == 'count' &&
        item.modelType == 'Sleep') {
      var t = todayAttributedTime(wa, item);
      if (t == null) {
        final idx = todayDowIndex0Mon();
        if (item.selectedAttribute.toLowerCase().contains('start') && idx > 0) {
          t = attributedTimeOnDay(wa, item, idx - 1);
        }
      }
      if (t != null) {
        return wakeIsOnTrack(item, t)
            ? AppColors.goalOnTrack
            : AppColors.goalMissed;
      }
    }
    if (item.cadence == GoalCadence.daily &&
        item.aggregation == 'count' &&
        item.modelType != 'Sleep') {
      return _colorForDayState(_todayInWeek(item, weekStart));
    }
  }

  return _colorForDayState(_todayInWeek(item, weekStart));
}

Color _colorForDayState(GoalDailyState? day) {
  if (day == null) {
    return AppColors.slate500;
  }
  return switch (day.state) {
    GoalDayState.hit => AppColors.goalOnTrack,
    GoalDayState.miss => AppColors.goalMissed,
    GoalDayState.pending => AppColors.goalAtRisk,
    GoalDayState.notDue => AppColors.slate400,
  };
}

List<_Dot> _dotsFor(ActionGoalWeekItem item, DateTime weekStart) {
  final days = normalizeDailyStates(item.dailyState, weekStart);
  return days.map((d) {
    final isToday = isSameCalendarDate(d.date, todayDate);
    if (d.state == GoalDayState.hit) {
      return isToday ? _Dot.todayOk : _Dot.ok;
    }
    if (d.state == GoalDayState.miss) {
      return isToday ? _Dot.todayMiss : _Dot.miss;
    }
    if (d.state == GoalDayState.notDue) {
      return isToday ? _Dot.todayOff : _Dot.off;
    }
    return isToday ? _Dot.todayProg : _Dot.pend;
  }).toList();
}

class _LabelExtras2 {
  const _LabelExtras2({
    this.subline,
    this.progress,
    this.progressColor,
    this.progressBeforeSubline = false,
    this.lastBorder = true,
  });

  final String? subline;
  final double? progress;
  final Color? progressColor;
  final bool progressBeforeSubline;
  final bool lastBorder;
}

/// Derives subline + progress for duration rows from [weekActions]. Returns null
/// for goals that keep a plain row (e.g. Wake, Yoga, weekly count).
_LabelExtras2? _goalRowExtrasFor(
  ActionGoalWeekItem item,
  WeekActions? weekActions,
) {
  if (weekActions == null) {
    return null;
  }
  if (item.cadence == GoalCadence.daily &&
      item.aggregation == 'sum' &&
      item.metric == 'duration') {
    final t = todaySoFarDuration(weekActions, item);
    if (t == null) {
      return null;
    }
    final tv = formatTargetValue(item);
    final targetSec = item.target.value;
    final prog = targetSec > 0
        ? (t.inSeconds / targetSec).clamp(0, 1).toDouble()
        : 0.0;
    final isReading = item.modelType == 'Reading';
    return _LabelExtras2(
      subline: 'Today: ${formatDurationShort(t, useDashForZero: false)} of $tv',
      progress: prog,
      progressColor: isReading ? AppColors.dotTodayProg : AppColors.dotMiss,
    );
  }
  if (item.cadence == GoalCadence.weekly &&
      item.aggregation == 'sum' &&
      item.metric == 'duration') {
    final list = actionsForGoal(weekActions, item);
    final wk = weekTotalDuration(
      list,
      capAtNow: isWeekCurrent(weekActions.weekStart),
    );
    final targetSec = item.target.value.toInt();
    final remSec = (targetSec - wk.inSeconds);
    final rem = remSec > 0 ? remSec : 0;
    final tv = formatTargetValue(item);
    final wkStr = formatDurationShort(wk, useDashForZero: false);
    final remStr = formatDurationShort(
      Duration(seconds: rem),
      useDashForZero: false,
    );
    final dl = daysLeftInSelectedWeek(weekActions);
    final prog = targetSec > 0
        ? (wk.inSeconds / targetSec).clamp(0, 1).toDouble()
        : 0.0;
    final isDance = item.modelType == 'Dance';
    return _LabelExtras2(
      subline: '$wkStr of $tv — $remStr remaining, $dl days left',
      progress: prog,
      progressColor: isDance ? AppColors.dotTodayProg : AppColors.dotOk,
      progressBeforeSubline: true,
      lastBorder: !isDance,
    );
  }
  return null;
}

Widget _buildDailyRow(
  BuildContext context,
  ActionGoalWeekItem item,
  DateTime weekStart,
  WeekActions? weekActions,
) {
  final dots = _dotsFor(item, weekStart);
  final ex = _goalRowExtrasFor(item, weekActions);
  return _GoalRow(
    onTap: () => GoalsPage.openDetail(context, item.id),
    title: item.label,
    status: _rightStatusText(item, weekStart, weekActions),
    statusColor: _rightStatusColor(item, weekStart, weekActions),
    dots: dots,
    subline: ex?.subline,
    progress: ex?.progress,
    progressColor: ex?.progressColor,
    lastBorder: ex?.lastBorder ?? true,
    progressBeforeSubline: ex?.progressBeforeSubline ?? false,
  );
}

Widget _buildWeeklyRow(
  BuildContext context,
  ActionGoalWeekItem item,
  DateTime weekStart,
  WeekActions? weekActions,
) {
  final dots = _dotsFor(item, weekStart);
  final ex = _goalRowExtrasFor(item, weekActions);
  if (item.label.contains('Gym')) {
    final c = weeklySlotCounts(item, weekStart);
    return _GymWeekRow(
      onTap: () => GoalsPage.openDetail(context, item.id),
      title: item.label,
      status: _rightStatusText(item, weekStart, weekActions),
      statusColor: _rightStatusColor(item, weekStart, weekActions),
      hits: c.hit,
      target: c.total,
      daysLeft: c.daysLeft,
    );
  }
  return _GoalRow(
    onTap: () => GoalsPage.openDetail(context, item.id),
    title: item.label,
    status: _rightStatusText(item, weekStart, weekActions),
    statusColor: _rightStatusColor(item, weekStart, weekActions),
    dots: dots,
    subline: ex?.subline,
    progress: ex?.progress,
    progressColor: ex?.progressColor,
    lastBorder: ex?.lastBorder ?? true,
    progressBeforeSubline: ex?.progressBeforeSubline ?? false,
  );
}

class _GoalsWeekNavigator extends StatelessWidget {
  const _GoalsWeekNavigator({
    required this.weekStart,
    required this.onPreviousWeek,
    required this.onNextWeek,
  });

  final DateTime weekStart;
  final VoidCallback onPreviousWeek;
  final VoidCallback onNextWeek;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: _SectionLabel(text: 'Week')),
        _MonthIconButton(
          icon: SolarLinearIcons.altArrowLeft,
          onTap: onPreviousWeek,
          tooltip: 'Previous week',
        ),
        SizedBox(
          width: 132,
          child: Text(
            _weekRangeLabel(weekStart),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.slate700,
            ),
          ),
        ),
        _MonthIconButton(
          icon: SolarLinearIcons.altArrowRight,
          onTap: onNextWeek,
          tooltip: 'Next week',
        ),
      ],
    );
  }
}

class _GoalsMonthHeatmap extends StatelessWidget {
  const _GoalsMonthHeatmap({
    required this.visibleMonth,
    required this.score,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onDayTap,
  });

  final DateTime visibleMonth;
  final AsyncValue<ActionGoalsMonthScore> score;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<DateTime> onDayTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: score.maybeWhen(
                data: (data) =>
                    _ConsistencyScoreLabel(consistency: data.consistency),
                orElse: () => const _SectionLabel(text: 'Month'),
              ),
            ),
            _MonthIconButton(
              icon: SolarLinearIcons.altArrowLeft,
              onTap: onPreviousMonth,
              tooltip: 'Previous month',
            ),
            SizedBox(
              width: 116,
              child: Text(
                _monthLabel(visibleMonth),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.slate700,
                ),
              ),
            ),
            _MonthIconButton(
              icon: SolarLinearIcons.altArrowRight,
              onTap: onNextMonth,
              tooltip: 'Next month',
            ),
          ],
        ),
        const SizedBox(height: 8),
        const _WeekdayHeader(),
        const SizedBox(height: 4),
        score.when(
          data: (data) => _MonthScoreGrid(
            monthStart: visibleMonth,
            days: data.days,
            onDayTap: onDayTap,
          ),
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text(
              'Could not load month: $e',
              style: const TextStyle(fontSize: 12, color: AppColors.slate500),
            ),
          ),
        ),
      ],
    );
  }
}

class _ConsistencyScoreLabel extends StatelessWidget {
  const _ConsistencyScoreLabel({required this.consistency});

  final ActionGoalMonthConsistency consistency;

  @override
  Widget build(BuildContext context) {
    final text = consistency.ratio == null
        ? '--'
        : '${(consistency.ratio!.clamp(0, 1) * 100).round()}%';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Consistency',
          style: TextStyle(
            fontSize: 10,
            height: 1.1,
            fontWeight: FontWeight.w600,
            color: AppColors.slate400,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            height: 1.05,
            fontWeight: FontWeight.w800,
            color: AppColors.slate700,
          ),
        ),
      ],
    );
  }
}

class _MonthIconButton extends StatelessWidget {
  const _MonthIconButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        color: AppColors.slate500,
        constraints: const BoxConstraints.tightFor(width: 34, height: 34),
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader();

  @override
  Widget build(BuildContext context) {
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Row(
      children: labels
          .map(
            (label) => Expanded(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.slate400,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _MonthScoreGrid extends StatelessWidget {
  const _MonthScoreGrid({
    required this.monthStart,
    required this.days,
    required this.onDayTap,
  });

  final DateTime monthStart;
  final List<ActionGoalMonthScoreDay> days;
  final ValueChanged<DateTime> onDayTap;

  @override
  Widget build(BuildContext context) {
    final cells = _scoreCells(monthStart, days);
    return GridView.builder(
      itemCount: cells.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        childAspectRatio: 1.05,
      ),
      itemBuilder: (context, index) {
        final day = cells[index];
        if (day == null) {
          return const SizedBox.shrink();
        }
        return _MonthScoreCell(day: day, onTap: () => onDayTap(day.date));
      },
    );
  }
}

class _MonthScoreCell extends StatelessWidget {
  const _MonthScoreCell({required this.day, required this.onTap});

  final ActionGoalMonthScoreDay day;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = goalMonthHeatmapColor(day);
    final active = !day.future && day.total > 0 && day.ratio != null;
    final textColor = active ? Colors.white : AppColors.slate500;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: active ? color : AppColors.slate200,
              width: 0.5,
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${day.date.day}',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.1,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                Text(
                  '${day.hit}/${day.total}',
                  style: TextStyle(
                    fontSize: 9,
                    height: 1.1,
                    fontWeight: FontWeight.w600,
                    color: textColor.withValues(alpha: active ? 0.9 : 0.75),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

List<ActionGoalMonthScoreDay?> _scoreCells(
  DateTime monthStart,
  List<ActionGoalMonthScoreDay> days,
) {
  final start = monthStartOf(monthStart);
  final byKey = <int, ActionGoalMonthScoreDay>{};
  for (final day in days) {
    byKey[dayKey(day.date)] = day;
  }
  final leading = start.weekday - 1;
  final total = leading + daysInCalendarMonth(start);
  final paddedTotal = ((total + 6) ~/ 7) * 7;
  return List.generate(paddedTotal, (i) {
    if (i < leading) {
      return null;
    }
    final date = start.add(Duration(days: i - leading));
    if (date.month != start.month) {
      return null;
    }
    return byKey[dayKey(date)] ??
        ActionGoalMonthScoreDay(
          date: date,
          hit: 0,
          total: 0,
          ratio: null,
          future: date.isAfter(todayDate),
        );
  });
}

String _monthLabel(DateTime monthStart) {
  const names = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  final m = monthStartOf(monthStart);
  return '${names[m.month - 1]} ${m.year}';
}

String _weekRangeLabel(DateTime weekStart) {
  final m0 = DateTime(weekStart.year, weekStart.month, weekStart.day);
  final sun = m0.add(const Duration(days: 6));
  return '${_shortDateLabel(m0)} - ${_shortDateLabel(sun)}';
}

String _shortDateLabel(DateTime date) {
  const names = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${names[date.month - 1]} ${date.day}';
}

class _AddGoalRow extends StatelessWidget {
  const _AddGoalRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              Icon(
                SolarLinearIcons.addCircle,
                size: 18,
                color: AppColors.slate400,
              ),
              SizedBox(width: 8),
              Text(
                'Add a goal',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.slate500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.slate600,
        ),
      ),
    );
  }
}

enum _Dot { ok, miss, pend, off, todayOk, todayMiss, todayProg, todayOff }

class _GoalRow extends StatelessWidget {
  const _GoalRow({
    this.onTap,
    required this.title,
    required this.status,
    required this.statusColor,
    required this.dots,
    this.subline,
    this.progress,
    this.progressColor,
    this.lastBorder = true,
    this.progressBeforeSubline = false,
  });

  final VoidCallback? onTap;
  final String title;
  final String status;
  final Color statusColor;
  final List<_Dot> dots;
  final String? subline;
  final double? progress;
  final Color? progressColor;
  final bool lastBorder;
  final bool progressBeforeSubline;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: lastBorder
            ? const Border(
                bottom: BorderSide(color: AppColors.slate200, width: 0.5),
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.slate900,
                  ),
                ),
              ),
              Text(
                status,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: statusColor,
                ),
              ),
            ],
          ),
          if (dots.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: List.generate(7, (i) {
                return Padding(
                  padding: EdgeInsets.only(right: i < 6 ? 4 : 0),
                  child: _GoalDot(kind: dots[i]),
                );
              }),
            ),
            const SizedBox(height: 2),
            Row(
              children: List.generate(7, (i) {
                const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                return Padding(
                  padding: EdgeInsets.only(right: i < 6 ? 4 : 0),
                  child: SizedBox(
                    width: 12,
                    child: Text(
                      letters[i],
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 9,
                        height: 1,
                        color: AppColors.slate400,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
          if (progress != null &&
              progressColor != null &&
              progressBeforeSubline) ...[
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: AppColors.slate200,
                valueColor: AlwaysStoppedAnimation<Color>(progressColor!),
              ),
            ),
          ],
          if (subline != null) ...[
            const SizedBox(height: 6),
            Text(
              subline!,
              style: const TextStyle(fontSize: 11, color: AppColors.slate500),
            ),
          ],
          if (progress != null &&
              progressColor != null &&
              !progressBeforeSubline) ...[
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: AppColors.slate200,
                valueColor: AlwaysStoppedAnimation<Color>(progressColor!),
              ),
            ),
          ],
        ],
      ),
    );
    if (onTap == null) {
      return child;
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, child: child),
    );
  }
}

class _GoalDot extends StatelessWidget {
  const _GoalDot({required this.kind});

  final _Dot kind;

  @override
  Widget build(BuildContext context) {
    const size = 12.0;
    switch (kind) {
      case _Dot.ok:
        return Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            color: AppColors.dotOk,
            shape: BoxShape.circle,
          ),
        );
      case _Dot.miss:
        return Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            color: AppColors.dotMiss,
            shape: BoxShape.circle,
          ),
        );
      case _Dot.pend:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.slate200, width: 1.5),
          ),
        );
      case _Dot.off:
        return Center(
          child: Container(
            width: 8,
            height: 2,
            decoration: BoxDecoration(
              color: AppColors.slate300,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        );
      case _Dot.todayOk:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.dotOk,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.slate900, width: 2),
          ),
        );
      case _Dot.todayMiss:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.dotMiss,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.slate900, width: 2),
          ),
        );
      case _Dot.todayProg:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.dotTodayProg,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.slate900, width: 2),
          ),
        );
      case _Dot.todayOff:
        return Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.slate900, width: 1.5),
          ),
          child: Container(
            width: 6,
            height: 2,
            decoration: BoxDecoration(
              color: AppColors.slate300,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        );
    }
  }
}

class _GymWeekRow extends StatelessWidget {
  const _GymWeekRow({
    this.onTap,
    required this.title,
    required this.status,
    required this.statusColor,
    required this.hits,
    required this.target,
    required this.daysLeft,
  });

  final VoidCallback? onTap;
  final String title;
  final String status;
  final Color statusColor;
  final int hits;
  final int target;
  final int daysLeft;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.slate200, width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.slate900,
                  ),
                ),
              ),
              Text(
                status,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: statusColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < target; i++) ...[
                    if (i > 0) const SizedBox(width: 4),
                    if (i < hits.clamp(0, target))
                      _GymCheck()
                    else
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.slate200,
                            width: 1.5,
                          ),
                        ),
                      ),
                  ],
                ],
              ),
              Text(
                daysLeft == 0
                    ? 'last day of week'
                    : '$daysLeft days left in week',
                style: const TextStyle(fontSize: 11, color: AppColors.slate500),
              ),
            ],
          ),
        ],
      ),
    );
    if (onTap == null) {
      return child;
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, child: child),
    );
  }
}

class _GymCheck extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: const BoxDecoration(
        color: AppColors.calGreen,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: const Icon(
        SolarLinearIcons.checkRead,
        size: 10,
        color: Colors.white,
      ),
    );
  }
}
