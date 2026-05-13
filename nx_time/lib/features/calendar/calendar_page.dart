import 'dart:math' as math;

import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:solar_icon_pack/solar_icon_pack.dart';

import 'package:nx_time/core/formatting/time_format.dart';
import 'package:nx_time/core/theme/app_theme.dart';
import 'package:nx_time/data/providers.dart';
import 'package:nx_time/core/widgets/nx_tab_header.dart';
import 'package:nx_time/features/action_detail/action_detail_page.dart';
import 'package:nx_time/features/shell/nx_app_menu_button.dart';
import 'package:nx_time/features/action_detail/action_detail_view_model.dart';
import 'package:nx_time/features/calendar/calendar_providers.dart';
import 'package:nx_time/features/calendar/calendar_view_model.dart';
import 'package:nx_time/features/log_edit/log_edit_page.dart';
import 'package:nx_time/features/today/action_fold.dart';
import 'package:nx_time/features/today/log_view_model.dart';
import 'package:nx_time/features/today/widgets/log_row.dart';

class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

enum _CalendarView { actions, logs, tasks, stats }

class _CalendarPageState extends ConsumerState<CalendarPage> {
  /// Index 0 = Monday … 6 = Sunday; `null` until first frame picks default for the week.
  int? _selectedDayIndex;

  _CalendarView _view = _CalendarView.actions;

  /// When true, the tab shows week-level pie + distribution bars instead of the day grid.
  bool _weekOverview = false;

  static const _sky600 = Color(0xFF0284C7);

  void _prevWeek() {
    final m = ref.read(currentWeekProvider);
    final m0 = DateTime(m.year, m.month, m.day);
    ref
        .read(currentWeekProvider.notifier)
        .setLocalWeekMonday(m0.subtract(const Duration(days: 7)));
    setState(() {
      _selectedDayIndex = null;
      _view = _CalendarView.actions;
      _weekOverview = false;
    });
  }

  void _nextWeek() {
    final m = ref.read(currentWeekProvider);
    final m0 = DateTime(m.year, m.month, m.day);
    ref
        .read(currentWeekProvider.notifier)
        .setLocalWeekMonday(m0.add(const Duration(days: 7)));
    setState(() {
      _selectedDayIndex = null;
      _view = _CalendarView.actions;
      _weekOverview = false;
    });
  }

  String _weekRangeLabel(DateTime monday) {
    final sun = monday.add(const Duration(days: 6));
    final m = DateFormat.MMMd().format(monday);
    final s = DateFormat.MMMd().format(sun);
    return '$m – $s';
  }

  int _defaultDayIndexForWeek(DateTime monday) {
    final n = DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    for (var i = 0; i < 7; i++) {
      final d = monday.add(Duration(days: i));
      if (d.year == today.year &&
          d.month == today.month &&
          d.day == today.day) {
        return i;
      }
    }
    return 2;
  }

  void _openActivityDetail(
    BuildContext context,
    CalendarDayData dayData,
    UmbrellaRow row,
    ModelTypeColors colors,
  ) {
    final dayLabel = DateFormat.MMMd().format(dayData.day);
    final args = row.children.isNotEmpty
        ? activityDetailArgsForUmbrella(row, dayLabel, colors)
        : activityDetailArgsForAction(row.umbrella, dayLabel, colors);
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => ActivityDetailPage(args: args)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final monday = ref.watch(currentWeekProvider);
    final m0 = DateTime(monday.year, monday.month, monday.day);
    final async = ref.watch(calendarWeekProvider);
    final colors = modelTypeColorsOrFallback(
      ref.watch(modelTypeColorsProvider),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NxTabHeader(
          title: 'Calendar',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () => setState(() => _weekOverview = !_weekOverview),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                tooltip: _weekOverview ? 'Week schedule' : 'Week overview',
                icon: Icon(
                  SolarLinearIcons.pieChart2,
                  size: 22,
                  color: _weekOverview ? AppColors.accent : AppColors.slate400,
                ),
              ),
              const NxAppMenuButton(),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          child: Row(
            children: [
              IconButton(
                onPressed: _prevWeek,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                icon: const Icon(
                  SolarLinearIcons.altArrowLeft,
                  size: 18,
                  color: _sky600,
                ),
              ),
              Expanded(
                child: Text(
                  _weekRangeLabel(m0),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.slate900,
                  ),
                ),
              ),
              IconButton(
                onPressed: _nextWeek,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                icon: const Icon(
                  SolarLinearIcons.altArrowRight,
                  size: 18,
                  color: _sky600,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: async.when(
            data: (days) {
              if (_weekOverview) {
                final weekStats = _statsForWeek(days, colors);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _WeekOverviewBody(weekStats: weekStats)),
                  ],
                );
              }
              final idx = _selectedDayIndex ?? _defaultDayIndexForWeek(m0);
              final safeIdx = idx.clamp(0, 6);
              final selected = days[safeIdx];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                    child: SizedBox(
                      height: 160,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < days.length; i++) ...[
                            if (i > 0) const SizedBox(width: 6),
                            Expanded(
                              child: _DayColumn(
                                dayData: days[i],
                                selected: i == safeIdx,
                                colors: colors,
                                onTap: () => setState(() {
                                  _selectedDayIndex = i;
                                }),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Divider(
                      height: 1,
                      thickness: 1,
                      color: AppColors.slate200,
                    ),
                  ),
                  Expanded(
                    child: _CalendarDayPanel(
                      dayData: selected,
                      view: _view,
                      colors: colors,
                      onSelectView: (v) => setState(() => _view = v),
                      onRowTap: (row) =>
                          _openActivityDetail(context, selected, row, colors),
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Could not load calendar: $e')),
          ),
        ),
      ],
    );
  }
}

/// Reference `tab-calendar.html` + `styles.css` `.cal-act-row` / `.cal-color`.
class _CalActRow extends StatelessWidget {
  const _CalActRow({
    required this.color,
    required this.timeRange,
    required this.title,
    required this.duration,
    this.onTap,
    this.showBottomBorder = true,
  });

  final Color color;
  final String timeRange;
  final String title;
  final String duration;
  final VoidCallback? onTap;
  final bool showBottomBorder;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        hoverColor: AppColors.slate50.withValues(alpha: 0.8),
        splashColor: AppColors.slate100.withValues(alpha: 0.5),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: showBottomBorder
                ? const Border(
                    bottom: BorderSide(color: AppColors.slate200, width: 0.5),
                  )
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 4,
                    constraints: const BoxConstraints(minHeight: 18),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 85,
                    child: Text(
                      timeRange,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.25,
                        color: AppColors.slate600,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.25,
                        color: AppColors.slate900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    duration,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.25,
                      color: AppColors.slate400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CalendarDayPanel extends StatelessWidget {
  const _CalendarDayPanel({
    required this.dayData,
    required this.view,
    required this.colors,
    required this.onSelectView,
    required this.onRowTap,
  });

  final CalendarDayData dayData;
  final _CalendarView view;
  final ModelTypeColors colors;
  final ValueChanged<_CalendarView> onSelectView;
  final void Function(UmbrellaRow row) onRowTap;

  @override
  Widget build(BuildContext context) {
    final heading = DateFormat('EEEE, MMM d').format(dayData.day);
    final rows = dayData.rows;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            border: const Border(bottom: BorderSide(color: AppColors.slate100)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  heading,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.slate900,
                  ),
                ),
              ),
              Row(
                children: [
                  _CalViewIcon(
                    icon: SolarLinearIcons.running,
                    tooltip: 'Actions',
                    selected: view == _CalendarView.actions,
                    onTap: () => onSelectView(_CalendarView.actions),
                  ),
                  const SizedBox(width: 4),
                  _CalViewIcon(
                    icon: SolarLinearIcons.notebook,
                    tooltip: 'Daily logs',
                    selected: view == _CalendarView.logs,
                    onTap: () => onSelectView(_CalendarView.logs),
                  ),
                  const SizedBox(width: 4),
                  _CalViewIcon(
                    icon: SolarLinearIcons.checklistMinimalistic,
                    tooltip: 'Tasks',
                    selected: view == _CalendarView.tasks,
                    onTap: () => onSelectView(_CalendarView.tasks),
                  ),
                  const SizedBox(width: 4),
                  _CalViewIcon(
                    icon: SolarLinearIcons.chartSquare,
                    tooltip: 'Stats',
                    selected: view == _CalendarView.stats,
                    onTap: () => onSelectView(_CalendarView.stats),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: switch (view) {
            _CalendarView.tasks => const Center(
              child: Text(
                'No tasks',
                style: TextStyle(fontSize: 14, color: AppColors.slate500),
              ),
            ),
            _CalendarView.logs => _CalendarLogsList(day: dayData.day),
            _CalendarView.stats => _StatsList(
              stats: _statsForDay(dayData, colors),
            ),
            _CalendarView.actions =>
              rows.isEmpty
                  ? const Center(
                      child: Text(
                        'No actions',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.slate500,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 120),
                      itemCount: rows.length + 1,
                      itemBuilder: (context, i) {
                        if (i == rows.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 6),
                            child: Text(
                              'tap any row to view activity detail',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.slate400,
                              ),
                            ),
                          );
                        }
                        final row = rows[i];
                        final u = row.umbrella;
                        final bar = colors.forId(
                          u.modelTypeId,
                          name: u.modelTypeName,
                        );
                        final name = u.name.isNotEmpty
                            ? u.name
                            : (u.modelTypeName ?? 'Action');
                        final start = u.startTime;
                        final end = u.endTime;
                        return _CalActRow(
                          color: bar,
                          timeRange: _compactTimeRange(start, end),
                          title: name,
                          duration: formatDurationHm(start, end),
                          showBottomBorder: i < rows.length - 1,
                          onTap: () => onRowTap(row),
                        );
                      },
                    ),
          },
        ),
      ],
    );
  }
}

class _CalendarLogsList extends ConsumerWidget {
  const _CalendarLogsList({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(dailyLogsForDayProvider(day));

    return logsAsync.when(
      data: (logs) {
        if (logs.isEmpty) {
          return const Center(
            child: Text(
              'No logs',
              style: TextStyle(fontSize: 14, color: AppColors.slate500),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
          itemCount: logs.length,
          itemBuilder: (context, i) {
            final log = logs[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: LogRow(
                log: log,
                onTap: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          LogEditPage(mode: LogEditMode.edit, initial: log),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Could not load logs: $e',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.slate500),
          ),
        ),
      ),
    );
  }
}

class _CalViewIcon extends StatelessWidget {
  const _CalViewIcon({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: selected ? AppColors.slate900 : AppColors.slate100,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Icon(
              icon,
              size: 16,
              color: selected ? Colors.white : AppColors.slate600,
            ),
          ),
        ),
      ),
    );
  }
}

class _TypeStat {
  _TypeStat({required this.label, required this.color});

  final String label;
  final Color color;
  int totalMinutes = 0;
}

void _accumulateDayRowsInto(
  CalendarDayData dayData,
  ModelTypeColors colors,
  Map<int, _TypeStat> byType,
) {
  final dayStart = DateTime(
    dayData.day.year,
    dayData.day.month,
    dayData.day.day,
  );
  final dayEnd = dayStart.add(const Duration(days: 1));
  for (final r in dayData.rows) {
    final u = r.umbrella;
    var s = u.startTime;
    var e = u.endTime;
    if (s == null) continue;
    e ??= s.add(const Duration(hours: 1));
    if (s.isBefore(dayStart)) s = dayStart;
    if (e.isAfter(dayEnd)) e = dayEnd;
    if (!e.isAfter(s)) continue;
    final mins = e.difference(s).inMinutes;
    if (mins <= 0) continue;
    final id = u.modelTypeId;
    final stat = byType.putIfAbsent(
      id,
      () => _TypeStat(
        label: (u.modelTypeName != null && u.modelTypeName!.isNotEmpty)
            ? u.modelTypeName!
            : 'Type $id',
        color: colors.forId(id, name: u.modelTypeName),
      ),
    );
    stat.totalMinutes += mins;
  }
}

List<_TypeStat> _statsForDay(CalendarDayData dayData, ModelTypeColors colors) {
  final byType = <int, _TypeStat>{};
  _accumulateDayRowsInto(dayData, colors, byType);
  final list = byType.values.toList()
    ..sort((a, b) => b.totalMinutes.compareTo(a.totalMinutes));
  return list;
}

List<_TypeStat> _statsForWeek(
  List<CalendarDayData> days,
  ModelTypeColors colors,
) {
  final byType = <int, _TypeStat>{};
  for (final d in days) {
    _accumulateDayRowsInto(d, colors, byType);
  }
  final list = byType.values.toList()
    ..sort((a, b) => b.totalMinutes.compareTo(a.totalMinutes));
  return list;
}

String _formatHm(int totalMinutes) {
  final h = totalMinutes ~/ 60;
  final m = totalMinutes.remainder(60);
  if (h <= 0) return '${m}m';
  if (m == 0) return '${h}h';
  return '${h}h ${m}m';
}

class _StatsList extends StatelessWidget {
  const _StatsList({
    required this.stats,
    this.shrinkWrap = false,
    this.physics,
    this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 120),
  });

  final List<_TypeStat> stats;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) {
      return const Center(
        child: Text(
          'No actions',
          style: TextStyle(fontSize: 14, color: AppColors.slate500),
        ),
      );
    }
    final maxMinutes = stats.first.totalMinutes;
    return ListView.builder(
      shrinkWrap: shrinkWrap,
      physics: physics,
      padding: padding,
      itemCount: stats.length,
      itemBuilder: (context, i) {
        final s = stats[i];
        final fraction = maxMinutes <= 0 ? 0.0 : s.totalMinutes / maxMinutes;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: s.color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      s.label,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.slate900,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    _formatHm(s.totalMinutes),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.slate500,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: Stack(
                  children: [
                    Container(height: 6, color: AppColors.slate100),
                    FractionallySizedBox(
                      widthFactor: fraction.clamp(0.0, 1.0),
                      child: Container(height: 6, color: s.color),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Week summary: pie by type + same horizontal bars as the per-day Stats tab.
class _WeekOverviewBody extends StatelessWidget {
  const _WeekOverviewBody({required this.weekStats});

  final List<_TypeStat> weekStats;

  @override
  Widget build(BuildContext context) {
    if (weekStats.isEmpty) {
      return const Center(
        child: Text(
          'No actions',
          style: TextStyle(fontSize: 14, color: AppColors.slate500),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'This week',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.slate900,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _WeekPieChart(stats: weekStats),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                SizedBox(height: 8),
                Divider(height: 1, thickness: 1, color: AppColors.slate200),
                SizedBox(height: 8),
              ],
            ),
          ),
          _StatsList(
            stats: weekStats,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          ),
        ],
      ),
    );
  }
}

class _WeekPieChart extends StatelessWidget {
  const _WeekPieChart({required this.stats});

  final List<_TypeStat> stats;

  @override
  Widget build(BuildContext context) {
    final total = stats.fold<int>(0, (a, s) => a + s.totalMinutes);
    if (total <= 0) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final side = math.min(220.0, constraints.maxWidth);
          return Center(
            child: SizedBox(
              width: side,
              height: side,
              child: CustomPaint(
                painter: _WeekPiePainter(stats: stats, totalMinutes: total),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _WeekPiePainter extends CustomPainter {
  _WeekPiePainter({required this.stats, required this.totalMinutes});

  final List<_TypeStat> stats;
  final int totalMinutes;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 1;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.white
      ..strokeWidth = 1.5;
    var startAngle = -math.pi / 2;
    for (final s in stats) {
      if (s.totalMinutes <= 0) continue;
      final sweep = 2 * math.pi * (s.totalMinutes / totalMinutes);
      canvas.drawArc(
        rect,
        startAngle,
        sweep,
        true,
        Paint()
          ..style = PaintingStyle.fill
          ..color = s.color,
      );
      startAngle += sweep;
    }
    startAngle = -math.pi / 2;
    for (final s in stats) {
      if (s.totalMinutes <= 0) continue;
      final sweep = 2 * math.pi * (s.totalMinutes / totalMinutes);
      canvas.drawArc(rect, startAngle, sweep, true, edge);
      startAngle += sweep;
    }
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = AppColors.slate200
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _WeekPiePainter oldDelegate) {
    return oldDelegate.totalMinutes != totalMinutes ||
        oldDelegate.stats.length != stats.length;
  }
}

/// One flex segment in a 24h column: [flex] sums to 1440 minutes; [color] null = muted gap.
class _DayBarSeg {
  const _DayBarSeg({required this.flex, this.color});

  final int flex;
  final Color? color;
}

/// Stacked segments from local midnight → next midnight (1440 min). Gaps use [AppColors.calMuted].
List<_DayBarSeg> _segments24h(CalendarDayData dayData, ModelTypeColors colors) {
  final dayStart = DateTime(
    dayData.day.year,
    dayData.day.month,
    dayData.day.day,
  );
  final dayEnd = dayStart.add(const Duration(days: 1));
  const total = 24 * 60;
  final intervals = <({int startMin, int endMin, Color color})>[];
  for (final r in dayData.rows) {
    final u = r.umbrella;
    var s = u.startTime;
    var e = u.endTime;
    if (s == null) continue;
    e ??= s.add(const Duration(hours: 1));
    if (s.isBefore(dayStart)) s = dayStart;
    if (e.isAfter(dayEnd)) e = dayEnd;
    if (!e.isAfter(s)) continue;
    final startMin = s.difference(dayStart).inMinutes.clamp(0, total);
    final endMin = e.difference(dayStart).inMinutes.clamp(0, total);
    if (endMin <= startMin) continue;
    intervals.add((
      startMin: startMin,
      endMin: endMin,
      color: colors.forId(u.modelTypeId, name: u.modelTypeName),
    ));
  }
  intervals.sort((a, b) => a.startMin.compareTo(b.startMin));
  final out = <_DayBarSeg>[];
  var cursor = 0;
  for (final iv in intervals) {
    if (iv.startMin > cursor) {
      out.add(_DayBarSeg(flex: iv.startMin - cursor, color: null));
    }
    if (iv.endMin > cursor) {
      final from = math.max(cursor, iv.startMin);
      out.add(_DayBarSeg(flex: iv.endMin - from, color: iv.color));
      cursor = iv.endMin;
    }
  }
  if (cursor < total) {
    out.add(_DayBarSeg(flex: total - cursor, color: null));
  }
  return out;
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({
    required this.dayData,
    required this.selected,
    required this.colors,
    required this.onTap,
  });

  final CalendarDayData dayData;
  final bool selected;
  final ModelTypeColors colors;
  final VoidCallback onTap;

  static const _letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final letter = _letters[dayData.day.weekday - 1];
    final rows = dayData.rows;
    final isWeekend =
        dayData.day.weekday == DateTime.saturday ||
        dayData.day.weekday == DateTime.sunday;

    final Widget bar;
    if (rows.isEmpty) {
      bar = isWeekend
          ? DottedBorder(
              options: RoundedRectDottedBorderOptions(
                radius: const Radius.circular(4),
                color: selected ? AppColors.slate900 : AppColors.slate200,
                dashPattern: const [4, 4],
                strokeWidth: selected ? 1.5 : 1,
                padding: EdgeInsets.zero,
              ),
              child: Container(
                width: double.infinity,
                height: double.infinity,
                color: AppColors.slate100,
              ),
            )
          : Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: selected ? AppColors.slate900 : AppColors.slate200,
                  width: selected ? 1.5 : 1,
                ),
                color: AppColors.slate100,
              ),
            );
    } else {
      final segments = _segments24h(dayData, colors);
      bar = Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: selected ? AppColors.slate900 : AppColors.slate200,
            width: selected ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (final seg in segments)
              if (seg.flex > 0)
                Expanded(
                  flex: seg.flex,
                  child: Container(
                    width: double.infinity,
                    color: seg.color ?? AppColors.calMuted,
                  ),
                ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: bar),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              letter,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                color: selected ? AppColors.slate900 : AppColors.slate400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _compactTime(DateTime d) {
  var h = d.hour % 12;
  if (h == 0) h = 12;
  final m = d.minute.toString().padLeft(2, '0');
  final suffix = d.hour < 12 ? 'a' : 'p';
  return '$h:$m$suffix';
}

String _compactTimeRange(DateTime? start, DateTime? end) {
  if (start == null || end == null) return '—';
  return '${_compactTime(start)} – ${_compactTime(end)}';
}
