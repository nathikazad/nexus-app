import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:solar_icon_pack/solar_icon_pack.dart';

import 'package:nx_time/core/time/wall_clock_time.dart';
import 'package:nx_time/core/theme/app_theme.dart';
import 'package:nx_time/core/time/week_calendar.dart';
import 'package:nx_time/data/providers.dart';
import 'package:nx_time/domain/action/week_actions.dart';
import 'package:nx_time/domain/goals/action_goal.dart';
import 'package:nx_time/domain/goals/goal_day_state.dart';
import 'package:nx_time/features/calendar/calendar_providers.dart';
import 'package:nx_time/features/goals/goal_detail/goal_action_helpers.dart';
import 'package:nx_time/features/goals/goal_detail/goal_detail_helpers.dart';
import 'package:nx_time/features/goals/goal_detail/goal_detail_variant.dart';
import 'package:nx_time/features/goals/goal_edit/goal_edit_page.dart';
import 'package:nx_time/features/goals/goal_edit/goal_edit_view_model.dart';

/// Goal detail: loads this goal's current week + visible month from [goalRepositoryProvider].
class GoalDetailPage extends ConsumerStatefulWidget {
  const GoalDetailPage({super.key, required this.goalId});

  final int goalId;

  @override
  ConsumerState<GoalDetailPage> createState() => _GoalDetailPageState();
}

class _GoalDetailPageState extends ConsumerState<GoalDetailPage> {
  bool _loading = false;
  bool _monthLoading = false;
  Object? _error;
  Object? _monthError;
  ActionGoalWeekItem? _item;
  ActionGoalsMonth? _month;
  DateTime? _weekStart;
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    _visibleMonth = monthStartOf(DateTime.now());
    // ignore: discarded_futures
    _load();
  }

  @override
  void didUpdateWidget(covariant GoalDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.goalId != widget.goalId) {
      _visibleMonth = monthStartOf(DateTime.now());
      // ignore: discarded_futures
      _load();
    }
  }

  Future<void> _openEdit() async {
    final repo = ref.read(goalRepositoryProvider);
    try {
      final g = await repo.getById(widget.goalId);
      if (!mounted) return;
      if (g == null) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load goal to edit')),
        );
        return;
      }
      if (!context.mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => GoalEditPage(mode: GoalEditMode.edit, initial: g),
        ),
      );
      if (mounted) {
        // ignore: discarded_futures
        _load();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not open edit: $e')));
    }
  }

  Future<void> _load() async {
    final id = widget.goalId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(goalRepositoryProvider);
      final m = ref.read(currentWeekProvider);
      final monday = mondayOfWeek(m);
      final week = await repo.getActionGoalsWeek(weekStart: monday, goalId: id);
      if (week.items.isEmpty) {
        throw StateError('Goal not found');
      }
      final item = week.items.first;
      final month = await repo.getActionGoalsMonth(
        monthStart: _visibleMonth,
        goalId: id,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _item = item;
        _month = month;
        _weekStart = asStoredLocalWallClock(week.weekStart);
        _loading = false;
        _monthLoading = false;
        _monthError = null;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _loadMonth(DateTime monthStart) async {
    final normalized = monthStartOf(monthStart);
    setState(() {
      _visibleMonth = normalized;
      _monthLoading = true;
      _monthError = null;
    });
    try {
      final repo = ref.read(goalRepositoryProvider);
      final month = await repo.getActionGoalsMonth(
        monthStart: normalized,
        goalId: widget.goalId,
      );
      if (!mounted) return;
      setState(() {
        _month = month;
        _monthLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _monthError = e;
        _monthLoading = false;
      });
    }
  }

  void _changeMonth(int delta) {
    unawaited(_loadMonth(addCalendarMonths(_visibleMonth, delta)));
  }

  @override
  Widget build(BuildContext context) {
    final Widget content;
    if (_loading) {
      content = const Center(
        child: Padding(
          padding: EdgeInsets.all(48),
          child: CircularProgressIndicator(),
        ),
      );
    } else if (_error != null) {
      content = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Could not load goal',
                style: TextStyle(color: AppColors.slate700),
              ),
              const SizedBox(height: 8),
              Text(
                '$_error',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: AppColors.slate500),
              ),
              const SizedBox(height: 8),
              TextButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    } else if (_item != null && _month != null && _weekStart != null) {
      final item = _item!;
      final ws = _weekStart!;
      final eff = goalDetailVariantFor(item);
      content = switch (eff) {
        GoalDetailVariant.wake => _WakeBodyData(
          item: item,
          weekStart: ws,
          visibleMonth: _visibleMonth,
          month: _month!,
          monthLoading: _monthLoading,
          monthError: _monthError,
          onPreviousMonth: () => _changeMonth(-1),
          onNextMonth: () => _changeMonth(1),
        ),
        GoalDetailVariant.sleep => _SleepBodyData(
          item: item,
          weekStart: ws,
          visibleMonth: _visibleMonth,
          month: _month!,
          monthLoading: _monthLoading,
          monthError: _monthError,
          onPreviousMonth: () => _changeMonth(-1),
          onNextMonth: () => _changeMonth(1),
        ),
        GoalDetailVariant.gym => _GymBodyData(
          item: item,
          weekStart: ws,
          visibleMonth: _visibleMonth,
          month: _month!,
          monthLoading: _monthLoading,
          monthError: _monthError,
          onPreviousMonth: () => _changeMonth(-1),
          onNextMonth: () => _changeMonth(1),
        ),
      };
    } else {
      content = const SizedBox.shrink();
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DetailAppBar(
              onBack: () => Navigator.of(context).maybePop(),
              onEdit: () => unawaited(_openEdit()),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                child: content,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailAppBar extends StatelessWidget {
  const _DetailAppBar({required this.onBack, required this.onEdit});

  final VoidCallback onBack;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(
              SolarLinearIcons.arrowLeft,
              size: 22,
              color: AppColors.slate600,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
          const Expanded(
            child: Text(
              'GOAL',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
                color: AppColors.slate900,
              ),
            ),
          ),
          IconButton(
            onPressed: onEdit,
            icon: const Icon(
              SolarLinearIcons.pen,
              size: 22,
              color: AppColors.slate500,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            tooltip: 'Edit goal',
          ),
        ],
      ),
    );
  }
}

// --- Section chrome (reference: text-[10px] uppercase tracking-widest) ---
class _Kicker extends StatelessWidget {
  const _Kicker(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
        color: AppColors.slate500,
      ),
    );
  }
}

class _StreakPill extends StatelessWidget {
  const _StreakPill({
    required this.count,
    required this.unit,
    this.muted = false,
  });

  final int count;
  final String unit;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final fg = muted ? AppColors.slate500 : AppColors.accent;
    final bg = muted
        ? AppColors.slate100
        : AppColors.accentLight.withValues(alpha: 0.5);
    final numColor = muted ? AppColors.slate700 : AppColors.slate900;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(SolarBoldIcons.fire, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: numColor,
            ),
          ),
          const SizedBox(width: 3),
          Text(
            unit,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

class _WakeBodyData extends ConsumerWidget {
  const _WakeBodyData({
    required this.item,
    required this.weekStart,
    required this.visibleMonth,
    required this.month,
    required this.monthLoading,
    required this.monthError,
    required this.onPreviousMonth,
    required this.onNextMonth,
  });

  final ActionGoalWeekItem item;
  final DateTime weekStart;
  final DateTime visibleMonth;
  final ActionGoalsMonth month;
  final bool monthLoading;
  final Object? monthError;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = ref.watch(currentWeekProvider);
    final asyncWa = ref.watch(
      weekActionsProvider(DateTime(w.year, w.month, w.day)),
    );
    return asyncWa.when(
      data: (wa) => _wakeColumn(wa),
      loading: () => _wakeColumn(null),
      error: (_, __) => _wakeColumn(null),
    );
  }

  Widget _wakeColumn(WeekActions? wa) {
    final days = normalizeDailyStates(item.dailyState, weekStart);
    final hits = countHits(days);
    final sc = item.streak.current.streakCount;
    final thresholdLabel = thresholdWallClockFromFilter(item) ?? '7 AM';

    final thX = thresholdTrackPosition(item) ?? 0.75;
    DateTime? todayWake;
    if (wa != null && isWeekCurrent(wa.weekStart)) {
      todayWake = todayAttributedTime(wa, item);
    }
    final dotX = (todayWake != null)
        ? wakeTrackPositionFromTime(todayWake)
        : 0.0;
    final clockMain = (todayWake != null)
        ? formatHoursMinutes12h(todayWake)
        : '—';
    final clockPeriod = (todayWake != null) ? formatAmPm(todayWake) : '';
    final deltaLine = (wa != null && isWeekCurrent(wa.weekStart))
        ? wakeDeltaVsThresholdLine(item, todayWake)
        : null;
    final onTrack = wakeIsOnTrack(item, todayWake);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          item.label,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            height: 1.2,
            color: AppColors.slate900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          formatGoalSubline(item),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.slate500,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      clockMain,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w600,
                        color: AppColors.slate900,
                      ),
                    ),
                    if (clockPeriod.isNotEmpty) const SizedBox(width: 4),
                    if (clockPeriod.isNotEmpty)
                      Text(
                        clockPeriod,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.slate500,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.slate500,
                    ),
                    children: [
                      if (wa == null) ...[
                        const TextSpan(text: '…'),
                      ] else if (!isWeekCurrent(wa.weekStart)) ...[
                        const TextSpan(text: 'this week · '),
                        const TextSpan(
                          text: 'no data',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ] else if (deltaLine == null) ...[
                        const TextSpan(text: 'today · '),
                        const TextSpan(
                          text: 'no data',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ] else ...[
                        const TextSpan(text: 'today · '),
                        TextSpan(
                          text: deltaLine,
                          style: TextStyle(
                            color: onTrack
                                ? AppColors.goalOnTrack
                                : AppColors.goalMissed,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            _StreakPill(count: sc, unit: 'days', muted: sc == 0),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 32,
          child: LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              final tX = thX;
              final dX = dotX;
              return Stack(
                children: [
                  Center(
                    child: Container(height: 1, color: AppColors.slate200),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: w * tX,
                      height: 1,
                      child: const ColoredBox(color: AppColors.dotOk),
                    ),
                  ),
                  Positioned(
                    left: w * tX,
                    top: 0,
                    bottom: 0,
                    child: const VerticalDivider(
                      width: 1,
                      color: AppColors.slate700,
                      thickness: 1,
                    ),
                  ),
                  Positioned(
                    left: w * tX - 12,
                    top: -2,
                    child: Text(
                      thresholdLabel,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                        color: AppColors.slate700,
                      ),
                    ),
                  ),
                  if (wa != null && todayWake != null)
                    Positioned(
                      left: w * dX - 6,
                      top: 10,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: onTrack ? AppColors.dotOk : AppColors.dotMiss,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x330F172A),
                              blurRadius: 0.5,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '5 AM',
              style: TextStyle(fontSize: 9, color: AppColors.slate400),
            ),
            Text(
              '8 AM',
              style: TextStyle(fontSize: 9, color: AppColors.slate400),
            ),
          ],
        ),
        const SizedBox(height: 28),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const _Kicker('THIS WEEK'),
            Text.rich(
              TextSpan(
                style: const TextStyle(fontSize: 11, color: AppColors.slate500),
                children: [
                  TextSpan(
                    text: '$hits',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.slate700,
                    ),
                  ),
                  const TextSpan(text: ' of 7 hit'),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...List.generate(7, (i) {
          final t = wa == null ? null : attributedTimeOnDay(wa, item, i);
          final p = (t == null) ? 0.0 : wakeTrackPositionFromTime(t);
          final label = t == null ? '—' : formatHoursMinutes12h(t);
          return _wakeSwimRow(
            ['M', 'T', 'W', 'T', 'F', 'S', 'S'][i],
            p,
            label,
            days[i].state == GoalDayState.miss,
            isSameCalendarDate(days[i].date, todayDate),
            days[i].state == GoalDayState.pending,
          );
        }),
        const SizedBox(height: 8),
        const Row(
          children: [
            Text(
              '5 AM',
              style: TextStyle(fontSize: 10, color: AppColors.slate400),
            ),
            Expanded(child: Divider(height: 1, color: AppColors.slate100)),
            Text(
              '8 AM',
              style: TextStyle(fontSize: 10, color: AppColors.slate400),
            ),
          ],
        ),
        const SizedBox(height: 28),
        _GoalMonthCalendarSection(
          visibleMonth: visibleMonth,
          month: month,
          monthLoading: monthLoading,
          monthError: monthError,
          onPreviousMonth: onPreviousMonth,
          onNextMonth: onNextMonth,
        ),
        const SizedBox(height: 24),
        _HowMeasuredPanel(rows: howMeasuredRowsFor(item)),
        const SizedBox(height: 20),
        _BottomActions(deleteBlurb: deleteBlurbForModel(item.modelType)),
      ],
    );
  }
}

class _GoalMonthCalendarSection extends StatelessWidget {
  const _GoalMonthCalendarSection({
    required this.visibleMonth,
    required this.month,
    required this.monthLoading,
    required this.monthError,
    required this.onPreviousMonth,
    required this.onNextMonth,
  });

  final DateTime visibleMonth;
  final ActionGoalsMonth month;
  final bool monthLoading;
  final Object? monthError;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;

  @override
  Widget build(BuildContext context) {
    final item = month.items.isEmpty ? null : month.items.first;
    final daily = item?.dailyState ?? const <GoalDailyState>[];
    final score = goalMonthConsistencyScore(daily, visibleMonth);
    final cells = buildGoalMonthCalendarCells(daily, visibleMonth);
    final monthLabel = DateFormat('MMMM yyyy').format(visibleMonth);
    final percent = score.percent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const _Kicker('MONTH'),
            Text.rich(
              TextSpan(
                style: const TextStyle(fontSize: 11, color: AppColors.slate500),
                children: [
                  const TextSpan(text: 'consistency '),
                  TextSpan(
                    text: percent == null ? '--' : '$percent%',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.slate700,
                    ),
                  ),
                  if (score.denominator > 0)
                    TextSpan(text: ' (${score.hits}/${score.denominator})'),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _MonthNavButton(
              icon: Icons.chevron_left,
              onPressed: monthLoading ? null : onPreviousMonth,
            ),
            Expanded(
              child: Text(
                monthLabel,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.slate900,
                ),
              ),
            ),
            _MonthNavButton(
              icon: Icons.chevron_right,
              onPressed: monthLoading ? null : onNextMonth,
            ),
          ],
        ),
        if (monthLoading) ...[
          const SizedBox(height: 6),
          const LinearProgressIndicator(
            minHeight: 2,
            backgroundColor: AppColors.slate100,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
          ),
        ],
        if (monthError != null) ...[
          const SizedBox(height: 6),
          Text(
            'Could not load month: $monthError',
            style: const TextStyle(fontSize: 11, color: AppColors.goalMissed),
          ),
        ],
        const SizedBox(height: 10),
        Row(
          children: [
            for (final label in ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
              Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.slate400,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Column(
          children: List.generate((cells.length / 7).ceil(), (row) {
            final start = row * 7;
            final rowCells = cells.sublist(start, start + 7);
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  for (final cell in rowCells)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: _GoalMonthCellView(cell: cell),
                      ),
                    ),
                ],
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _MonthNavButton extends StatelessWidget {
  const _MonthNavButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      color: AppColors.slate600,
      disabledColor: AppColors.slate300,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      tooltip: icon == Icons.chevron_left ? 'Previous month' : 'Next month',
    );
  }
}

class _GoalMonthCellView extends StatelessWidget {
  const _GoalMonthCellView({required this.cell});

  final GoalMonthCalendarCell cell;

  @override
  Widget build(BuildContext context) {
    final isToday = isSameCalendarDate(cell.date, todayDate);
    final state = cell.state;
    final Color background;
    final Color foreground;
    Border? border;
    if (!cell.inMonth) {
      background = Colors.transparent;
      foreground = AppColors.slate300;
    } else {
      switch (state) {
        case GoalDayState.hit:
          background = AppColors.dotOk;
          foreground = Colors.white;
        case GoalDayState.miss:
          background = AppColors.dotMiss;
          foreground = Colors.white;
        case GoalDayState.pending:
        case null:
          background = AppColors.slate100;
          foreground = AppColors.slate400;
      }
    }
    if (isToday && cell.inMonth) {
      border = Border.all(color: AppColors.accent, width: 1.5);
    }
    return AspectRatio(
      aspectRatio: 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(8),
          border: border,
        ),
        child: Center(
          child: Text(
            '${cell.date.day}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: isToday ? FontWeight.w700 : FontWeight.w600,
              color: foreground,
            ),
          ),
        ),
      ),
    );
  }
}

Widget _wakeSwimRow(
  String letter,
  double pos,
  String time,
  bool miss,
  bool today,
  bool pending,
) {
  final dotColor = pending
      ? Colors.transparent
      : (miss ? AppColors.dotMiss : AppColors.dotOk);
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        SizedBox(
          width: 16,
          child: Text(
            letter,
            style: TextStyle(
              fontSize: 10,
              fontWeight: today ? FontWeight.w600 : FontWeight.w500,
              color: today
                  ? AppColors.accent
                  : (pending ? AppColors.slate300 : AppColors.slate400),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 12,
            decoration: BoxDecoration(
              border: Border.all(
                color: today ? AppColors.accent : Colors.transparent,
                width: 1,
              ),
              borderRadius: BorderRadius.circular(4),
              color: today
                  ? AppColors.accentLight.withValues(alpha: 0.3)
                  : null,
            ),
            child: LayoutBuilder(
              builder: (context, c) {
                final trackW = c.maxWidth;
                return Stack(
                  children: [
                    Center(
                      child: Container(height: 1, color: AppColors.slate100),
                    ),
                    if (!pending)
                      Positioned(
                        left: trackW * pos - 5,
                        top: 1,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: dotColor,
                            shape: BoxShape.circle,
                            border: today
                                ? Border.all(
                                    color: AppColors.slate900,
                                    width: 2,
                                  )
                                : null,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 44,
          child: Text(
            time,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 10,
              fontWeight: today ? FontWeight.w600 : FontWeight.w500,
              color: pending
                  ? AppColors.slate300
                  : (miss ? AppColors.goalMissed : AppColors.slate700),
            ),
          ),
        ),
      ],
    ),
  );
}

// =============================================================================
// Sleep layout: daily `sum` + `duration` (e.g. Sleep 8h, Reading 1hr)
// =============================================================================

class _SleepBodyData extends ConsumerWidget {
  const _SleepBodyData({
    required this.item,
    required this.weekStart,
    required this.visibleMonth,
    required this.month,
    required this.monthLoading,
    required this.monthError,
    required this.onPreviousMonth,
    required this.onNextMonth,
  });

  final ActionGoalWeekItem item;
  final DateTime weekStart;
  final DateTime visibleMonth;
  final ActionGoalsMonth month;
  final bool monthLoading;
  final Object? monthError;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = ref.watch(currentWeekProvider);
    return ref
        .watch(weekActionsProvider(DateTime(w.year, w.month, w.day)))
        .when(
          data: (wa) => _column(wa),
          loading: () => _column(null),
          error: (_, __) => _column(null),
        );
  }

  Widget _column(WeekActions? wa) {
    final days = normalizeDailyStates(item.dailyState, weekStart);
    final hits = countHits(days);
    final sc = item.streak.current.streakCount;
    final targetStr = formatTargetValue(item);
    final targetSec = item.target.value.toInt();
    final isDur = item.metric == 'duration';

    Duration? todayDur;
    if (wa != null && isWeekCurrent(wa.weekStart) && isDur) {
      todayDur = todaySoFarDuration(wa, item);
    }
    final todayLabel = (todayDur == null)
        ? '—'
        : formatDurationShort(todayDur, useDashForZero: false);
    final onTrackToday =
        isDur &&
        targetSec > 0 &&
        todayDur != null &&
        todayDur.inSeconds >= targetSec;
    final todayProg = (isDur && targetSec > 0 && todayDur != null)
        ? (todayDur.inSeconds / targetSec).clamp(0, 1).toDouble()
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          item.label,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: AppColors.slate900,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          formatGoalSubline(item),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.slate500,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  todayLabel,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w600,
                    color: AppColors.slate900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'today so far · $targetStr target',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.slate500,
                  ),
                ),
              ],
            ),
            _StreakPill(count: sc, unit: 'days', muted: sc == 0),
          ],
        ),
        if (isDur && targetSec > 0) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: todayProg,
              minHeight: 6,
              backgroundColor: AppColors.slate100,
              valueColor: AlwaysStoppedAnimation<Color>(
                onTrackToday ? AppColors.goalOnTrack : AppColors.dotTodayProg,
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const _Kicker('THIS WEEK'),
            Text.rich(
              TextSpan(
                style: const TextStyle(fontSize: 11, color: AppColors.slate500),
                children: [
                  TextSpan(
                    text: '$hits',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.slate700,
                    ),
                  ),
                  const TextSpan(text: ' of 7 hit'),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...List.generate(7, (i) {
          final st = days[i];
          final letter = ['M', 'T', 'W', 'T', 'F', 'S', 'S'][i];
          var dur = Duration.zero;
          if (wa != null) {
            dur = sumDurationForDay(
              wa,
              actionsForGoal(wa, item),
              i,
              capAtNow: isWeekCurrent(wa.weekStart) && i == todayDowIndex0Mon(),
              selectedAttribute: item.selectedAttribute,
            );
          }
          final isToday = isSameCalendarDate(st.date, todayDate);
          final line = (wa == null)
              ? '—'
              : formatDurationShort(dur, useDashForZero: false);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  child: Text(
                    letter,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isToday ? FontWeight.w600 : FontWeight.w500,
                      color: isToday ? AppColors.accent : AppColors.slate500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    line,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isToday ? FontWeight.w600 : FontWeight.w400,
                      color: st.state == GoalDayState.miss
                          ? AppColors.goalMissed
                          : AppColors.slate700,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 20),
        _GoalMonthCalendarSection(
          visibleMonth: visibleMonth,
          month: month,
          monthLoading: monthLoading,
          monthError: monthError,
          onPreviousMonth: onPreviousMonth,
          onNextMonth: onNextMonth,
        ),
        const SizedBox(height: 24),
        _HowMeasuredPanel(rows: howMeasuredRowsFor(item)),
        const SizedBox(height: 20),
        _BottomActions(deleteBlurb: deleteBlurbForModel(item.modelType)),
      ],
    );
  }
}

// =============================================================================
// Gym (weekly + slots) — see page-goal-detail-gym.html
// =============================================================================

class _GymBodyData extends ConsumerWidget {
  const _GymBodyData({
    required this.item,
    required this.weekStart,
    required this.visibleMonth,
    required this.month,
    required this.monthLoading,
    required this.monthError,
    required this.onPreviousMonth,
    required this.onNextMonth,
  });

  final ActionGoalWeekItem item;
  final DateTime weekStart;
  final DateTime visibleMonth;
  final ActionGoalsMonth month;
  final bool monthLoading;
  final Object? monthError;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = ref.watch(currentWeekProvider);
    return ref
        .watch(weekActionsProvider(DateTime(w.year, w.month, w.day)))
        .when(
          data: (wa) => _gymContent(wa: wa),
          loading: () => _gymContent(wa: null),
          error: (_, __) => _gymContent(wa: null),
        );
  }

  Widget _gymContent({required WeekActions? wa}) {
    final days = normalizeDailyStates(item.dailyState, weekStart);
    final hits = countHits(days);
    final sc = item.streak.current.streakCount;
    final isCount = item.aggregation == 'count';
    final tv = item.target.value.toDouble();
    final dl = daysLeftInMonSunWeek();
    final slots = item.meta?.preferredSlots;
    final targetStr = formatTargetValue(item);
    final thisWeekRight = isCount
        ? '$hits sessions logged'
        : (item.aggregation == 'sum' && item.metric == 'duration'
              ? 'target $targetStr'
              : 'time logged (see week)');
    final isDurSum =
        !isCount && item.aggregation == 'sum' && item.metric == 'duration';
    final total = (wa == null || !isDurSum)
        ? null
        : weekTotalDuration(actionsForGoal(wa, item), capAtNow: true);
    final durStr = (total == null)
        ? '—'
        : formatDurationShort(total, useDashForZero: false);
    final progressVal = isCount && tv > 0
        ? (hits / tv).clamp(0, 1).toDouble()
        : (isDurSum && total != null && item.target.value > 0
              ? (total.inSeconds / item.target.value).clamp(0, 1).toDouble()
              : 0.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          item.label,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: AppColors.slate900,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          formatGoalSubline(item),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.slate500,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (isCount)
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '$hits',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w600,
                      color: AppColors.slate900,
                    ),
                  ),
                  Text(
                    ' / ${item.target.value}',
                    style: const TextStyle(
                      fontSize: 18,
                      color: AppColors.slate400,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              )
            else if (isDurSum)
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    durStr,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w600,
                      color: AppColors.slate900,
                    ),
                  ),
                  Text(
                    ' of $targetStr',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.slate500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  const Text(
                    '—',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w600,
                      color: AppColors.slate900,
                    ),
                  ),
                  Text(
                    ' of $targetStr',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.slate500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            _StreakPill(count: sc, unit: 'weeks', muted: sc == 0),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          isCount
              ? 'sessions this week · $dl days left'
              : 'progress this week · $dl days left',
          style: const TextStyle(fontSize: 12, color: AppColors.slate500),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progressVal,
            minHeight: 6,
            backgroundColor: AppColors.slate100,
            valueColor: const AlwaysStoppedAnimation<Color>(
              AppColors.goalAtRisk,
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (slots != null && slots.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const _Kicker('PREFERRED SLOTS'),
              TextButton(
                onPressed: () {},
                child: const Text(
                  'edit',
                  style: TextStyle(fontSize: 11, color: AppColors.slate400),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(slots.length > 3 ? 3 : slots.length, (i) {
              final s = slots[i];
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: i < (slots.length > 3 ? 3 : slots.length) - 1
                        ? 8
                        : 0,
                  ),
                  child: _GymSlotCard(
                    day: s.dow,
                    done: s.hit == true,
                    missed: s.hit == false,
                    time: s.startTime,
                    sub: s.hit == true
                        ? '${s.durationMin} min'
                        : (s.hit == false
                              ? 'missed'
                              : '${s.startTime} scheduled'),
                  ),
                ),
              );
            }),
          ),
          if (item.meta?.autoGenerateTasks != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text.rich(
                TextSpan(
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.slate500,
                  ),
                  children: [
                    const TextSpan(
                      text: 'Auto-create tasks for these slots — ',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: AppColors.slate700,
                      ),
                    ),
                    TextSpan(
                      text: item.meta!.autoGenerateTasks! ? 'on' : 'off',
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const _Kicker('THIS WEEK'),
            Text(
              thisWeekRight,
              style: const TextStyle(fontSize: 11, color: AppColors.slate500),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _GymWeekStripData(days: days),
        const SizedBox(height: 8),
        const Text(
          '● scheduled slot   ● completed   ● missed',
          style: TextStyle(fontSize: 10, color: AppColors.slate400),
        ),
        const SizedBox(height: 20),
        _GoalMonthCalendarSection(
          visibleMonth: visibleMonth,
          month: month,
          monthLoading: monthLoading,
          monthError: monthError,
          onPreviousMonth: onPreviousMonth,
          onNextMonth: onNextMonth,
        ),
        const SizedBox(height: 24),
        _HowMeasuredPanel(rows: howMeasuredRowsFor(item)),
        const SizedBox(height: 20),
        _BottomActions(
          deleteBlurb: deleteBlurbForModel(item.modelType),
          editSub: editSubForModel(item.modelType),
        ),
      ],
    );
  }
}

class _GymWeekStripData extends StatelessWidget {
  const _GymWeekStripData({required this.days});

  final List<GoalDailyState> days;

  @override
  Widget build(BuildContext context) {
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Row(
      children: List.generate(7, (i) {
        final s = days[i];
        final isToday = isSameCalendarDate(s.date, todayDate);
        final dOnly = DateTime(s.date.year, s.date.month, s.date.day);
        final isFuture = dOnly.isAfter(todayDate);
        Color? fill;
        if (s.state == GoalDayState.hit) {
          fill = AppColors.dotOk;
        } else if (s.state == GoalDayState.miss) {
          fill = AppColors.dotMiss;
        } else if (isToday) {
          fill = null;
        } else if (isFuture) {
          fill = null;
        }
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 1),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              border: isToday ? Border.all(color: AppColors.accent) : null,
              color: isToday
                  ? AppColors.accentLight.withValues(alpha: 0.35)
                  : null,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  labels[i],
                  style: TextStyle(
                    fontSize: 10,
                    color: isToday
                        ? AppColors.accent
                        : (isFuture ? AppColors.slate300 : AppColors.slate400),
                    fontWeight: isToday ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: fill,
                    shape: BoxShape.circle,
                    border: fill == null
                        ? (isToday
                              ? Border.all(color: AppColors.slate300)
                              : (isFuture
                                    ? Border.all(color: AppColors.slate200)
                                    : null))
                        : null,
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _GymSlotCard extends StatelessWidget {
  const _GymSlotCard({
    required this.day,
    this.done = false,
    this.missed = false,
    required this.time,
    required this.sub,
  });

  final String day;
  final bool done;
  final bool missed;
  final String time;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: missed ? const Color(0xFFFFF1F2) : Colors.white,
        border: Border.all(
          color: missed ? const Color(0xFFFECACA) : AppColors.slate100,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                day,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.slate700,
                ),
              ),
              if (done)
                Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    color: AppColors.dotOk,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    SolarLinearIcons.checkRead,
                    size: 8,
                    color: Colors.white,
                  ),
                )
              else if (missed)
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFFCA5A5),
                      width: 1.5,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            time,
            style: TextStyle(
              fontSize: 10,
              color: missed ? AppColors.slate400 : AppColors.slate500,
            ),
          ),
          Text(
            sub,
            style: TextStyle(
              fontSize: 10,
              fontWeight: missed ? FontWeight.w600 : FontWeight.w500,
              color: missed ? AppColors.dotMiss : AppColors.slate700,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Shared panels
// =============================================================================
class _HowMeasuredPanel extends StatelessWidget {
  const _HowMeasuredPanel({required this.rows});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.slate100),
      ),
      collapsedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.slate100),
      ),
      backgroundColor: AppColors.slate50.withValues(alpha: 0.6),
      collapsedBackgroundColor: AppColors.slate50.withValues(alpha: 0.6),
      title: const Row(
        children: [
          Icon(SolarLinearIcons.settings, size: 16, color: AppColors.slate400),
          SizedBox(width: 6),
          Text(
            'HOW THIS IS MEASURED',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: AppColors.slate500,
            ),
          ),
        ],
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            children: rows
                .map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 120,
                          child: Text(
                            e.$1,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.slate400,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            e.$2,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.slate900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _BottomActions extends StatelessWidget {
  const _BottomActions({
    required this.deleteBlurb,
    this.editSub = 'Change threshold time or filter',
  });

  final String deleteBlurb;
  final String editSub;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Divider(color: AppColors.slate100, height: 1),
        const SizedBox(height: 8),
        _actionTile(
          icon: SolarLinearIcons.pen,
          title: 'Edit goal',
          subtitle: editSub,
        ),
        _actionTile(
          icon: SolarLinearIcons.pause,
          title: 'Pause',
          subtitle: 'Hide from the goals tab without deleting history',
        ),
        _actionTile(
          icon: SolarLinearIcons.trashBinMinimalistic,
          title: 'Delete goal',
          subtitle: deleteBlurb,
          danger: true,
        ),
      ],
    );
  }

  static Widget _actionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    bool danger = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: danger ? const Color(0xFFFFF1F2) : AppColors.slate100,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 18,
              color: danger ? AppColors.dotMiss : AppColors.slate600,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: danger ? AppColors.dotMiss : AppColors.slate900,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.slate500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
