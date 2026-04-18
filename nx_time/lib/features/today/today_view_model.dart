import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Action;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nx_time/core/formatting/date_label.dart';
import 'package:nx_time/core/formatting/time_format.dart';
import 'package:nx_time/core/theme/action_color_palette.dart';
import 'package:nx_time/data/providers.dart';
import 'package:nx_time/domain/action/action.dart';
import 'package:nx_time/features/today/widgets/time_map_segment.dart';

/// View-model types for the Today tab (presentation only).

enum TodayActivityKind {
  standard,
  flagged,
  current,
}

class TodayActivity {
  const TodayActivity({
    required this.title,
    required this.timeRangeLabel,
    required this.durationLabel,
    required this.barColor,
    this.kind = TodayActivityKind.standard,
    this.secondaryLine,
    this.liveElapsedLabel,
  });

  final String title;
  final String timeRangeLabel;
  final String durationLabel;
  final Color barColor;
  final TodayActivityKind kind;

  final String? secondaryLine;
  final String? liveElapsedLabel;
}

class ActivityCategory {
  const ActivityCategory({
    required this.label,
    required this.swatch,
  });

  final String label;
  final Color swatch;
}

class TodaySnapshot {
  const TodaySnapshot({
    required this.clockLabel,
    required this.titleLine,
    required this.timeMapSegments,
    required this.currentMarkerFraction,
    required this.legend,
    required this.activityBlockCount,
    required this.actions,
    required this.sourceActions,
  });

  final String clockLabel;
  final String titleLine;
  final List<TimeMapSegment> timeMapSegments;
  final double currentMarkerFraction;
  final List<ActivityCategory> legend;
  final int activityBlockCount;
  final List<TodayActivity> actions;

  /// Same order as [actions]; used for navigation to detail/edit.
  final List<Action> sourceActions;
}

/// Today tab snapshot — uses [actionRepositoryProvider] (fake or KGQL).
final todaySnapshotProvider = FutureProvider<TodaySnapshot>((ref) async {
  const tag = '[nx_time Today]';
  debugPrint('$tag snapshot provider: start');
  try {
    final user = await ref.watch(authenticatedUserProvider.future);
    debugPrint('$tag auth ready userId=${user.userId} preset=${user.preset}');
    final repo = ref.watch(actionRepositoryProvider);
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    debugPrint('$tag calling listForCalendarDay(day=$day)');
    final actions = await repo.listForCalendarDay(day);
    debugPrint('$tag listForCalendarDay returned ${actions.length} actions');
    final snap = buildTodaySnapshot(
      actions,
      day,
      nowForClock: now,
    );
    debugPrint('$tag buildTodaySnapshot done (rows=${snap.actions.length})');
    return snap;
  } catch (e, st) {
    debugPrint('$tag ERROR: $e');
    debugPrint('$tag $st');
    rethrow;
  }
});

/// Maps domain [Action] rows to [TodaySnapshot] for the Today tab.
///
/// [dayLocal] is the calendar day at local midnight; the bar covers `[dayLocal, dayLocal + 1d)`.
/// Only intervals that overlap that window appear (clipped to `[dayStart, dayEnd)`).
TodaySnapshot buildTodaySnapshot(
  List<Action> domainActions,
  DateTime dayLocal, {
  DateTime? nowForClock,
}) {
  final timeFmt = DateFormat.jm();
  final clockSource = nowForClock ?? DateTime.now();

  final dayStart = DateTime(dayLocal.year, dayLocal.month, dayLocal.day);
  final dayEnd = dayStart.add(const Duration(days: 1));
  final totalMs = dayEnd.difference(dayStart).inMilliseconds;

  final inDay =
      domainActions.where((m) => _actionOverlapsLocalDay(m, dayStart, dayEnd)).toList();

  final sorted = List<Action>.from(inDay)
    ..sort((a, b) {
      final sa = a.startTime;
      final sb = b.startTime;
      if (sa == null && sb == null) return a.id.compareTo(b.id);
      if (sa == null) return 1;
      if (sb == null) return -1;
      final cmp = sa.compareTo(sb);
      if (cmp != 0) return cmp;
      return a.id.compareTo(b.id);
    });

  final actions = <TodayActivity>[];
  final timeMapSegments = <TimeMapSegment>[];
  final legendEntries = <ActivityCategory>[];
  final seenTypeIds = <int>{};

  for (final m in sorted) {
    final start = m.startTime;
    final end = m.endTime;
    final title = m.name.isNotEmpty ? m.name : 'Action';
    final rangeLabel = formatTimeRange(timeFmt, start, end);
    final durationLabel = formatDurationHm(start, end);
    final color = barColorForModelTypeId(m.modelTypeId);
    final embeddedName = m.modelTypeName;
    final typeLabel = (embeddedName != null && embeddedName.isNotEmpty)
        ? embeddedName
        : 'Type ${m.modelTypeId}';

    if (seenTypeIds.add(m.modelTypeId)) {
      legendEntries.add(ActivityCategory(label: typeLabel, swatch: color));
    }

    actions.add(
      TodayActivity(
        title: title,
        timeRangeLabel: rangeLabel,
        durationLabel: durationLabel,
        barColor: color,
      ),
    );

    if (totalMs <= 0) continue;
    final seg = _segmentForActionInDay(
      m,
      dayStart,
      dayEnd,
      totalMs,
      color,
    );
    if (seg != null) {
      timeMapSegments.add(seg);
    }
  }

  final titleLine = todayTitleLine(dayLocal);
  final clockLabel = timeFmt.format(clockSource);

  return TodaySnapshot(
    clockLabel: clockLabel,
    titleLine: titleLine,
    timeMapSegments: timeMapSegments,
    currentMarkerFraction: _nowFractionForDay(dayStart, dayEnd, clockSource),
    legend: legendEntries,
    activityBlockCount: sorted.length,
    actions: actions,
    sourceActions: sorted,
  );
}

bool _actionOverlapsLocalDay(Action m, DateTime dayStart, DateTime dayEnd) {
  final start = m.startTime;
  final end = m.endTime;
  if (start == null && end == null) return false;
  final s = start ?? end!;
  final e = end ?? start!.add(const Duration(hours: 1));
  return s.isBefore(dayEnd) && e.isAfter(dayStart);
}

TimeMapSegment? _segmentForActionInDay(
  Action m,
  DateTime dayStart,
  DateTime dayEnd,
  int totalMs,
  Color color,
) {
  final start = m.startTime;
  final end = m.endTime;
  if (start == null) return null;

  var s = start;
  var e = end ?? start.add(const Duration(hours: 1));

  if (!e.isAfter(s)) return null;

  if (s.isBefore(dayStart)) s = dayStart;
  if (e.isAfter(dayEnd)) e = dayEnd;
  if (!e.isAfter(s)) return null;

  final startFrac = s.difference(dayStart).inMilliseconds / totalMs;
  final endFrac = e.difference(dayStart).inMilliseconds / totalMs;
  final widthFrac = (endFrac - startFrac).clamp(0.0, 1.0);
  if (widthFrac <= 0) return null;

  return TimeMapSegment.positioned(
    color: color,
    startFraction: startFrac.clamp(0.0, 1.0),
    widthFraction: widthFrac,
  );
}

double _nowFractionForDay(DateTime dayStart, DateTime dayEnd, DateTime now) {
  final total = dayEnd.difference(dayStart).inMilliseconds;
  if (total <= 0) return 0.75;
  if (now.isBefore(dayStart)) return 0;
  if (!now.isBefore(dayEnd)) return 1;
  return (now.difference(dayStart).inMilliseconds / total).clamp(0.0, 1.0);
}

