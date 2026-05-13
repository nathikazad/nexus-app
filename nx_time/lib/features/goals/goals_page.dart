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

class GoalsPage extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final m = ref.watch(currentWeekProvider);
    final monday = DateTime(m.year, m.month, m.day);
    final weekAsync = ref.watch(actionGoalsWeekProvider(monday));
    final weekActions = ref.watch(weekActionsProvider(monday));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const NxTabHeader(title: 'Goals'),
        Expanded(
          child: weekAsync.when(
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
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                children: [
                  const SizedBox(height: 10),
                  const _SectionLabel(text: 'Daily goals'),
                  ...daily.map((item) => _buildDailyRow(context, item, ws, wa)),
                  const SizedBox(height: 14),
                  const _SectionLabel(text: 'Weekly goals'),
                  ...weekly.map(
                    (item) => _buildWeeklyRow(context, item, ws, wa),
                  ),
                  _AddGoalRow(onTap: () => GoalsPage.openCreate(context)),
                ],
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(48),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load goals: $e',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.slate500,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
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

class _AddGoalRow extends StatelessWidget {
  const _AddGoalRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              const Icon(
                SolarLinearIcons.addCircle,
                size: 18,
                color: AppColors.slate400,
              ),
              const SizedBox(width: 8),
              Text(
                'Add a goal',
                style: const TextStyle(
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

enum _Dot { ok, miss, pend, todayOk, todayMiss, todayProg }

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
