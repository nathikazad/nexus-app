import 'package:intl/intl.dart';
import 'package:nx_db/nx_db.dart';

import '../app_theme.dart';
import 'models/activity_category.dart';
import 'models/time_map_segment.dart';
import 'models/today_activity.dart';
import 'models/today_snapshot.dart';

/// Maps KGQL [Model] rows (Action + descendants) to [TodaySnapshot] for the Today tab.
///
/// This is intentionally simple until client-side fold/collapse (`today_calendar_rendering.md`)
/// is implemented; titles and times come from [Model.name] and `start_time` / `end_time`
/// attributes when present.
TodaySnapshot snapshotFromActionModels(List<Model> models, DateTime dayLocal) {
  final timeFmt = DateFormat.jm();
  final actions = <TodayActivity>[];

  for (final m in models) {
    final start = _readDateTimeAttr(m, 'start_time');
    final end = _readDateTimeAttr(m, 'end_time');
    final rangeLabel = _formatRange(timeFmt, start, end);
    final durationLabel = _formatDuration(start, end);

    actions.add(
      TodayActivity(
        title: m.name.isNotEmpty ? m.name : 'Activity',
        timeRangeLabel: rangeLabel,
        durationLabel: durationLabel,
        barColor: AppColors.routineGray,
      ),
    );
  }

  final titleLine = 'Today — ${DateFormat('EEE, MMM d').format(dayLocal)}';
  final clockLabel = timeFmt.format(DateTime.now());

  return TodaySnapshot(
    clockLabel: clockLabel,
    titleLine: titleLine,
    timeMapSegments: _placeholderSegments,
    currentMarkerFraction: 0.75,
    legend: _placeholderLegend,
    activityBlockCount: models.length,
    actions: actions,
  );
}

DateTime? _readDateTimeAttr(Model m, String key) {
  final raw = m.attributes?[key];
  if (raw == null) return null;
  if (raw is DateTime) return raw;
  if (raw is String) return DateTime.tryParse(raw);
  return null;
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

const _placeholderSegments = <TimeMapSegment>[
  TimeMapSegment(color: AppColors.sleepBlue, flex: 32),
  TimeMapSegment(color: AppColors.routineGray, flex: 5),
  TimeMapSegment(color: AppColors.exerciseGreen, flex: 8),
  TimeMapSegment(color: AppColors.routineGray, flex: 5),
  TimeMapSegment(color: AppColors.accent, flex: 25),
  TimeMapSegment(color: AppColors.slate100, flex: 25),
];

const _placeholderLegend = <ActivityCategory>[
  ActivityCategory(label: 'Sleep', swatch: AppColors.sleepBlue),
  ActivityCategory(label: 'Work', swatch: AppColors.accent),
  ActivityCategory(label: 'Exercise', swatch: AppColors.exerciseGreen),
  ActivityCategory(label: 'Eat/Cook', swatch: AppColors.eatYellow),
  ActivityCategory(label: 'Outdoors', swatch: AppColors.outdoorsTeal),
  ActivityCategory(label: 'Routine', swatch: AppColors.routineGray),
];
