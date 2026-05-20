import 'package:flutter/material.dart' hide Action;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nx_time/core/formatting/time_format.dart';
import 'package:nx_time/core/time/action_calendar_overlap.dart';
import 'package:nx_time/data/providers.dart';
import 'package:nx_time/domain/action/action.dart';
import 'package:nx_time/features/calendar/calendar_providers.dart';
import 'package:nx_time/features/today/action_fold.dart';
import 'package:nx_time/features/today/widgets/time_map_segment.dart';

/// View-model types for the Today tab (presentation only).

enum TodayActivityKind { standard, flagged, current }

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

/// A row with inline-expandable child actions (from [foldDayActions]).
class TodayUmbrellaActivity extends TodayActivity {
  const TodayUmbrellaActivity({
    required super.title,
    required super.timeRangeLabel,
    required super.durationLabel,
    required super.barColor,
    super.kind,
    super.secondaryLine,
    super.liveElapsedLabel,
    required this.children,
    required this.umbrellaAction,
  });

  final List<TodayActivity> children;
  final Action umbrellaAction;

  int get childCount => children.length;
}

class ActivityCategory {
  const ActivityCategory({required this.label, required this.swatch});

  final String label;
  final Color swatch;
}

class TodaySnapshot {
  const TodaySnapshot({
    required this.clockLabel,
    required this.titleLine,
    required this.dayDateLabel,
    required this.timeMapSegments,
    required this.currentMarkerFraction,
    required this.legend,
    required this.activityBlockCount,
    required this.actions,
    required this.sourceActions,
    required this.umbrellaRows,
    required this.dayActions,
  });

  final String clockLabel;
  final String titleLine;

  /// Calendar line for the focused day, e.g. "Sat, Apr 18" (for activity detail, not the header title).
  final String dayDateLabel;
  final List<TimeMapSegment> timeMapSegments;
  final double currentMarkerFraction;
  final List<ActivityCategory> legend;
  final int activityBlockCount;
  final List<TodayActivity> actions;

  /// One [Action] per visible row (the umbrella / root); same order as [actions].
  final List<Action> sourceActions;

  /// Fold output for umbrella detail / child navigation.
  final List<UmbrellaRow> umbrellaRows;

  /// All actions overlapping the calendar day (before fold), for id → name lookup.
  final List<Action> dayActions;
}

/// Today tab snapshot — combines [weekActionsProvider] (same week store as
/// Calendar) with [modelTypeColorsProvider] (in-memory) via
/// [modelTypeColorsOrFallback] so the shell never blocks on colors while they load.
///
/// Returns [AsyncValue] (not a [FutureProvider]) so the shell’s [AsyncValue.when]
/// gets the default [skipLoadingOnRefresh] behavior: on action invalidation the
/// previous snapshot stays visible (like [calendarWeekProvider]) instead of a
/// full-screen spinner.
final todaySnapshotProvider = Provider<AsyncValue<TodaySnapshot>>((ref) {
  const tag = '[nx_time Today]';
  final monday = ref.watch(todayMondayProvider);
  final weekAsync = ref.watch(weekActionsProvider(monday));
  final colors = modelTypeColorsOrFallback(ref.watch(modelTypeColorsProvider));

  return weekAsync.when(
    data: (week) {
      try {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final i = today.weekday - DateTime.monday; // 0..6: Mon..Sun
        return AsyncValue.data(
          buildTodaySnapshot(
            week.byDay[i],
            today,
            nowForClock: now,
            colors: colors,
          ),
        );
      } catch (e, st) {
        debugPrint('$tag $e\n$st');
        return AsyncValue<TodaySnapshot>.error(e, st);
      }
    },
    error: (e, st) => AsyncValue<TodaySnapshot>.error(e, st),
    loading: () => const AsyncValue<TodaySnapshot>.loading(),
  );
});

TodayActivity _activityFromAction(
  Action m,
  DateFormat timeFmt,
  ModelTypeColors colors,
) {
  final start = m.startTime;
  final end = m.endTime;
  final modelTypeName = m.modelTypeName;
  final title = m.name.isNotEmpty
      ? m.name
      : (modelTypeName != null && modelTypeName.isNotEmpty)
      ? modelTypeName
      : 'Action';
  final rangeLabel = formatTimeRange(timeFmt, start, end);
  final durationLabel = formatDurationHm(start, end);
  final color = colors.forId(m.modelTypeId, name: m.modelTypeName);
  return TodayActivity(
    title: title,
    timeRangeLabel: rangeLabel,
    durationLabel: durationLabel,
    barColor: color,
  );
}

/// Maps domain [Action] rows to [TodaySnapshot] for the Today tab.
///
/// [dayLocal] is the calendar day at local midnight; the bar covers `[dayLocal, dayLocal + 1d)`.
/// Only intervals that overlap that window appear (clipped to `[dayStart, dayEnd)`).
TodaySnapshot buildTodaySnapshot(
  List<Action> domainActions,
  DateTime dayLocal, {
  DateTime? nowForClock,
  ModelTypeColors colors = ModelTypeColors.fallback,
}) {
  final timeFmt = DateFormat.jm();
  final clockSource = nowForClock ?? DateTime.now();

  final dayStart = DateTime(dayLocal.year, dayLocal.month, dayLocal.day);
  final dayEnd = dayStart.add(const Duration(days: 1));
  final totalMs = dayEnd.difference(dayStart).inMilliseconds;

  final inDay = domainActions
      .where((m) => actionOverlapsHalfOpen(m, dayStart, dayEnd))
      .toList();

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

  final rows = foldDayActions(sorted);
  final actions = <TodayActivity>[];
  final timeMapSegments = <TimeMapSegment>[];
  final legendEntries = <ActivityCategory>[];
  final seenTypeIds = <int>{};
  final sourceActions = <Action>[];
  final umbrellaRows = <UmbrellaRow>[];

  void addLegendFor(Action m) {
    final embeddedName = m.modelTypeName;
    final typeLabel = (embeddedName != null && embeddedName.isNotEmpty)
        ? embeddedName
        : 'Type ${m.modelTypeId}';
    final color = colors.forId(m.modelTypeId, name: m.modelTypeName);
    if (seenTypeIds.add(m.modelTypeId)) {
      legendEntries.add(ActivityCategory(label: typeLabel, swatch: color));
    }
  }

  for (final row in rows) {
    final u = row.umbrella;
    addLegendFor(u);
    for (final c in row.children) {
      addLegendFor(c);
    }

    final umbrellaActivity = _activityFromAction(u, timeFmt, colors);
    sourceActions.add(u);
    umbrellaRows.add(row);

    if (row.children.isEmpty) {
      actions.add(umbrellaActivity);
    } else {
      final childActivities = row.children
          .map((c) => _activityFromAction(c, timeFmt, colors))
          .toList();
      actions.add(
        TodayUmbrellaActivity(
          title: umbrellaActivity.title,
          timeRangeLabel: umbrellaActivity.timeRangeLabel,
          durationLabel: umbrellaActivity.durationLabel,
          barColor: umbrellaActivity.barColor,
          kind: umbrellaActivity.kind,
          secondaryLine: umbrellaActivity.secondaryLine,
          liveElapsedLabel: umbrellaActivity.liveElapsedLabel,
          children: childActivities,
          umbrellaAction: u,
        ),
      );
    }

    if (totalMs <= 0) continue;
    final seg = _segmentForActionInDay(
      u,
      dayStart,
      dayEnd,
      totalMs,
      colors.forId(u.modelTypeId, name: u.modelTypeName),
    );
    if (seg != null) {
      timeMapSegments.add(seg);
    }
  }

  final dayDateLabel = DateFormat('EEE, MMM d').format(dayLocal);
  const titleLine = 'Actions';
  final clockLabel = timeFmt.format(clockSource);

  return TodaySnapshot(
    clockLabel: clockLabel,
    titleLine: titleLine,
    dayDateLabel: dayDateLabel,
    timeMapSegments: timeMapSegments,
    currentMarkerFraction: _nowFractionForDay(dayStart, dayEnd, clockSource),
    legend: legendEntries,
    activityBlockCount: rows.length,
    actions: actions,
    sourceActions: sourceActions,
    umbrellaRows: umbrellaRows,
    dayActions: sorted,
  );
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
