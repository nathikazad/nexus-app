import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nx_db/nx_db.dart';

import 'models/activity_category.dart';
import 'models/time_map_segment.dart';
import 'models/today_activity.dart';
import 'models/today_snapshot.dart';

/// Maps KGQL [Model] rows (Action + descendants) to [TodaySnapshot] for the Today tab.
///
/// [dayLocal] is the calendar day at local midnight; the bar covers `[dayLocal, dayLocal + 1d)`.
/// Only intervals that overlap that window appear (clipped to `[dayStart, dayEnd)`).
///
/// **Timestamps:** Values are treated as **local wall-clock** (what the DB stores). If the API
/// returns UTC (`Z`), we **do not** shift with [DateTime.toLocal]; we reinterpret the UTC
/// component numbers as local time so e.g. 23:00–06:00 stays same clock face and the bar
/// clips overnight sleep to 23:00–24:00 on the selected day.
///
/// Legend labels use [Model.modelType] from `get_kgql_models` embedded **`struct.model_type`**
/// (requested in [buildActionActivityStruct]); no separate model-types fetch.
TodaySnapshot snapshotFromActionModels(
  List<Model> models,
  DateTime dayLocal,
) {
  final timeFmt = DateFormat.jm();

  final dayStart = DateTime(dayLocal.year, dayLocal.month, dayLocal.day);
  final dayEnd = dayStart.add(const Duration(days: 1));
  final totalMs = dayEnd.difference(dayStart).inMilliseconds;

  final inDay = models.where((m) => _modelOverlapsLocalDay(m, dayStart, dayEnd)).toList();

  final sorted = List<Model>.from(inDay)
    ..sort((a, b) {
      final sa = _readDateTimeAttr(a, 'start_time');
      final sb = _readDateTimeAttr(b, 'start_time');
      if (sa == null && sb == null) return a.id.compareTo(b.id);
      if (sa == null) return 1;
      if (sb == null) return -1;
      final cmp =
          _asStoredLocalWallClock(sa).compareTo(_asStoredLocalWallClock(sb));
      if (cmp != 0) return cmp;
      return a.id.compareTo(b.id);
    });

  final actions = <TodayActivity>[];
  final timeMapSegments = <TimeMapSegment>[];
  final legendEntries = <ActivityCategory>[];
  final seenTypeIds = <int>{};

  for (final m in sorted) {
    final start = _readDateTimeAttr(m, 'start_time');
    final end = _readDateTimeAttr(m, 'end_time');
    final title = m.name.isNotEmpty ? m.name : 'Activity';
    final rangeLabel = _formatRange(
      timeFmt,
      start != null ? _asStoredLocalWallClock(start) : null,
      end != null ? _asStoredLocalWallClock(end) : null,
    );
    final durationLabel = _formatDuration(
      start != null ? _asStoredLocalWallClock(start) : null,
      end != null ? _asStoredLocalWallClock(end) : null,
    );
    final color = _barColorForModelTypeId(m.modelTypeId);
    final embeddedName = m.modelType?.name;
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
    final seg = _segmentForModelInDay(
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

  final titleLine = 'Today — ${DateFormat('EEE, MMM d').format(dayLocal)}';
  final clockLabel = timeFmt.format(DateTime.now());

  return TodaySnapshot(
    clockLabel: clockLabel,
    titleLine: titleLine,
    timeMapSegments: timeMapSegments,
    currentMarkerFraction: _nowFractionForDay(dayStart, dayEnd),
    legend: legendEntries,
    activityBlockCount: sorted.length,
    actions: actions,
  );
}

/// True if [start_time]/[end_time] overlap `[dayStart, dayEnd)` (wall-clock, see [_asStoredLocalWallClock]).
bool _modelOverlapsLocalDay(Model m, DateTime dayStart, DateTime dayEnd) {
  final start = _readDateTimeAttr(m, 'start_time');
  final end = _readDateTimeAttr(m, 'end_time');
  if (start == null && end == null) return false;
  final s = _asStoredLocalWallClock(start ?? end!);
  final e = _asStoredLocalWallClock(end ?? start!.add(const Duration(hours: 1)));
  return s.isBefore(dayEnd) && e.isAfter(dayStart);
}

TimeMapSegment? _segmentForModelInDay(
  Model m,
  DateTime dayStart,
  DateTime dayEnd,
  int totalMs,
  Color color,
) {
  final start = _readDateTimeAttr(m, 'start_time');
  final end = _readDateTimeAttr(m, 'end_time');
  if (start == null) return null;

  var s = _asStoredLocalWallClock(start);
  var e = _asStoredLocalWallClock(end ?? start.add(const Duration(hours: 1)));

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

double _nowFractionForDay(DateTime dayStart, DateTime dayEnd) {
  final now = DateTime.now();
  final total = dayEnd.difference(dayStart).inMilliseconds;
  if (total <= 0) return 0.75;
  if (now.isBefore(dayStart)) return 0;
  if (!now.isBefore(dayEnd)) return 1;
  return (now.difference(dayStart).inMilliseconds / total).clamp(0.0, 1.0);
}

/// Stable distinct color per concrete model type (`modelTypeId`); same type → same color.
Color _barColorForModelTypeId(int modelTypeId) {
  const golden = 0x9E3779B9;
  final hue = (modelTypeId * golden) % 360;
  return HSLColor.fromAHSL(1.0, hue.toDouble(), 0.52, 0.48).toColor();
}

DateTime? _readDateTimeAttr(Model m, String key) {
  final raw = m.attributes?[key];
  if (raw == null) return null;
  if (raw is DateTime) return raw;
  if (raw is String) return DateTime.tryParse(raw);
  return null;
}

/// Interprets DB datetimes as **local wall clock** (no offset shift).
///
/// GraphQL/JSON often returns `...Z` even when the stored instant is meant as local civil time.
/// Using [DateTime.toLocal] then moves 23:00/06:00 incorrectly and breaks clipping to midnight.
DateTime _asStoredLocalWallClock(DateTime dt) {
  if (dt.isUtc) {
    return DateTime(
      dt.year,
      dt.month,
      dt.day,
      dt.hour,
      dt.minute,
      dt.second,
      dt.millisecond,
      dt.microsecond,
    );
  }
  return dt;
}

String _formatRange(DateFormat timeFmt, DateTime? start, DateTime? end) {
  if (start == null && end == null) return '—';
  if (start != null && end != null) {
    return '${timeFmt.format(start)} – ${timeFmt.format(end)}';
  }
  if (start != null) return timeFmt.format(start);
  return timeFmt.format(end!);
}

String _formatDuration(DateTime? start, DateTime? end) {
  if (start == null || end == null) return '—';
  final d = end.difference(start);
  if (d.inMinutes <= 0) return '—';
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  if (h > 0) return '${h}h ${m}m';
  return '${m}m';
}

