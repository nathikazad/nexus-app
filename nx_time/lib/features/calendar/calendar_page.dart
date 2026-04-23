import 'dart:math' as math;

import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:solar_icon_pack/solar_icon_pack.dart';

import 'package:nx_time/core/formatting/time_format.dart';
import 'package:nx_time/core/theme/action_color_palette.dart';
import 'package:nx_time/core/theme/app_theme.dart';
import 'package:nx_time/core/widgets/nx_tab_header.dart';
import 'package:nx_time/features/action_detail/action_detail_page.dart';
import 'package:nx_time/features/action_detail/action_detail_view_model.dart';
import 'package:nx_time/features/calendar/calendar_providers.dart';
import 'package:nx_time/features/calendar/calendar_view_model.dart';
import 'package:nx_time/features/today/action_fold.dart';

class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  /// Index 0 = Monday … 6 = Sunday; `null` until first frame picks default for the week.
  int? _selectedDayIndex;

  bool _showTasksView = false;

  static const _sky600 = Color(0xFF0284C7);

  void _prevWeek() {
    final m = ref.read(currentWeekProvider);
    final m0 = DateTime(m.year, m.month, m.day);
    ref.read(currentWeekProvider.notifier).setLocalWeekMonday(
          m0.subtract(const Duration(days: 7)),
        );
    setState(() {
      _selectedDayIndex = null;
      _showTasksView = false;
    });
  }

  void _nextWeek() {
    final m = ref.read(currentWeekProvider);
    final m0 = DateTime(m.year, m.month, m.day);
    ref.read(currentWeekProvider.notifier).setLocalWeekMonday(
          m0.add(const Duration(days: 7)),
        );
    setState(() {
      _selectedDayIndex = null;
      _showTasksView = false;
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
      if (d.year == today.year && d.month == today.month && d.day == today.day) {
        return i;
      }
    }
    return 2;
  }

  void _openActivityDetail(
    BuildContext context,
    CalendarDayData dayData,
    UmbrellaRow row,
  ) {
    final dayLabel = DateFormat.MMMd().format(dayData.day);
    final args = row.children.isNotEmpty
        ? activityDetailArgsForUmbrella(
            row,
            'Today — $dayLabel',
          )
        : activityDetailArgsForAction(
            row.umbrella,
            'Today — $dayLabel',
          );
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ActivityDetailPage(args: args),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final monday = ref.watch(currentWeekProvider);
    final m0 = DateTime(monday.year, monday.month, monday.day);
    final async = ref.watch(calendarWeekProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const NxTabHeader(title: 'Calendar'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          child: Row(
            children: [
              IconButton(
                onPressed: _prevWeek,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                icon: const Icon(SolarLinearIcons.altArrowLeft, size: 18, color: _sky600),
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
                icon: const Icon(SolarLinearIcons.altArrowRight, size: 18, color: _sky600),
              ),
            ],
          ),
        ),
        Expanded(
          child: async.when(
            data: (days) {
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
                                onTap: () => setState(() {
                                  _selectedDayIndex = i;
                                  _showTasksView = false;
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
                    child: Divider(height: 1, thickness: 1, color: AppColors.slate200),
                  ),
                  Expanded(
                    child: _CalendarDayPanel(
                      dayData: selected,
                      showTasks: _showTasksView,
                      onToggleActions: () => setState(() => _showTasksView = false),
                      onToggleTasks: () => setState(() => _showTasksView = true),
                      onRowTap: (row) => _openActivityDetail(context, selected, row),
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
    required this.showTasks,
    required this.onToggleActions,
    required this.onToggleTasks,
    required this.onRowTap,
  });

  final CalendarDayData dayData;
  final bool showTasks;
  final VoidCallback onToggleActions;
  final VoidCallback onToggleTasks;
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
                  _CalViewChip(
                    label: 'Actions',
                    selected: !showTasks,
                    onTap: onToggleActions,
                  ),
                  const SizedBox(width: 4),
                  _CalViewChip(
                    label: 'Tasks',
                    selected: showTasks,
                    onTap: onToggleTasks,
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: showTasks
              ? const Center(
                  child: Text(
                    'No tasks',
                    style: TextStyle(fontSize: 14, color: AppColors.slate500),
                  ),
                )
              : rows.isEmpty
                  ? const Center(
                      child: Text(
                        'No actions',
                        style: TextStyle(fontSize: 14, color: AppColors.slate500),
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
                        final bar = barColorForModelTypeId(u.modelTypeId);
                        final name = u.name.isNotEmpty ? u.name : (u.modelTypeName ?? 'Action');
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
        ),
      ],
    );
  }
}

class _CalViewChip extends StatelessWidget {
  const _CalViewChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: selected ? AppColors.slate900 : AppColors.slate100,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: selected ? Colors.white : AppColors.slate600,
            ),
          ),
        ),
      ),
    );
  }
}

/// One flex segment in a 24h column: [flex] sums to 1440 minutes; [color] null = muted gap.
class _DayBarSeg {
  const _DayBarSeg({required this.flex, this.color});

  final int flex;
  final Color? color;
}

/// Stacked segments from local midnight → next midnight (1440 min). Gaps use [AppColors.calMuted].
List<_DayBarSeg> _segments24h(CalendarDayData dayData) {
  final dayStart = DateTime(dayData.day.year, dayData.day.month, dayData.day.day);
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
      color: barColorForModelTypeId(u.modelTypeId),
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
    required this.onTap,
  });

  final CalendarDayData dayData;
  final bool selected;
  final VoidCallback onTap;

  static const _letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final letter = _letters[dayData.day.weekday - 1];
    final rows = dayData.rows;
    final isWeekend =
        dayData.day.weekday == DateTime.saturday || dayData.day.weekday == DateTime.sunday;

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
      final segments = _segments24h(dayData);
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
