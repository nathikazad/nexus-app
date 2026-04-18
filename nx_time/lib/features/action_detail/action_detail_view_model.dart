import 'package:flutter/material.dart' hide Action;
import 'package:intl/intl.dart';

import 'package:nx_time/app_theme.dart';
import 'package:nx_time/core/theme/action_color_palette.dart';
import 'package:nx_time/domain/action/action.dart';
import 'package:nx_time/features/today/today_view_model.dart';

/// Matches reference `page-activity-detail-sleep` / `page-activity-detail-deep-work`.
enum ActivityDetailLayout {
  sleep,
  deepWork,
}

enum LinkedTaskProgress {
  partialBlue,
  doneGreen,
}

class LinkedTaskItem {
  const LinkedTaskItem({
    required this.title,
    required this.subtitle,
    required this.progress,
  });

  final String title;
  final String subtitle;
  final LinkedTaskProgress progress;
}

class ActivityDetailArgs {
  const ActivityDetailArgs({
    required this.layout,
    required this.detailTitle,
    required this.categoryPillLabel,
    required this.categoryPillBackground,
    required this.categoryPillForeground,
    required this.categoryDotColor,
    required this.dateLabel,
    required this.startTime,
    required this.startSuffix,
    required this.endTime,
    required this.endSuffix,
    required this.durationCenter,
    this.tasks = const [],
    required this.wearablePhotoLabel,
    this.sourceAction,
    this.description,
  });

  final ActivityDetailLayout layout;
  final String detailTitle;
  final String? description;
  final String categoryPillLabel;
  final Color categoryPillBackground;
  final Color categoryPillForeground;
  final Color categoryDotColor;
  final String dateLabel;

  final String startTime;
  final String startSuffix;
  final String endTime;
  final String endSuffix;
  final String durationCenter;

  final List<LinkedTaskItem> tasks;
  final String wearablePhotoLabel;

  /// When non-null, this row came from the repository and can be edited or deleted.
  final Action? sourceAction;

  int get linkedTaskCount => tasks.length;
}

/// Builds detail UI from a loaded [Action].
ActivityDetailArgs activityDetailArgsForAction(Action model, String snapshotTitleLine) {
  final dateLabel = _dateFromSnapshotTitle(snapshotTitleLine);
  final sl = model.startTime;
  final el = model.endTime;
  final typeName = model.modelTypeName ?? '';
  final layout =
      typeName == 'Sleep' ? ActivityDetailLayout.sleep : ActivityDetailLayout.deepWork;
  final startParts = _splitTimeForDisplay(sl);
  final endParts = _splitTimeForDisplay(el);
  final bar = barColorForModelTypeId(model.modelTypeId);
  final style = categoryPillStyleFromBarColor(bar);
  final typeLabel = (typeName.isNotEmpty) ? typeName : 'Type ${model.modelTypeId}';

  return ActivityDetailArgs(
    layout: layout,
    detailTitle: model.name.isNotEmpty ? model.name : (model.modelTypeName ?? 'Action'),
    categoryPillLabel: typeLabel,
    categoryPillBackground: style.background,
    categoryPillForeground: style.foreground,
    categoryDotColor: style.dot,
    dateLabel: dateLabel,
    startTime: startParts.$1,
    startSuffix: startParts.$2,
    endTime: endParts.$1,
    endSuffix: endParts.$2,
    durationCenter: _formatDurationDetail(sl, el),
    tasks: const [],
    wearablePhotoLabel: 'View photos ▶',
    sourceAction: model,
    description: _notesFromAction(model),
  );
}

String? _notesFromAction(Action model) {
  final d = model.description?.trim();
  if (d == null || d.isEmpty) return null;
  return d;
}

(String, String) _splitTimeForDisplay(DateTime? dt) {
  if (dt == null) return ('—', '');
  final hm = DateFormat('h:mm').format(dt);
  final ap = DateFormat('a').format(dt);
  return (hm, ' $ap');
}

String _formatDurationDetail(DateTime? start, DateTime? end) {
  if (start == null || end == null) return '—';
  final d = end.difference(start);
  if (d.inMinutes <= 0) return '—';
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  if (h > 0) return '${h}h ${m}m';
  return '${m}m';
}

ActivityDetailArgs activityDetailArgsForTodayRow(
  TodayActivity activity,
  String snapshotTitleLine,
) {
  final dateLabel = _dateFromSnapshotTitle(snapshotTitleLine);
  final t = activity.title.toLowerCase();

  if (t.contains('sleep')) {
    return ActivityDetailArgs(
      layout: ActivityDetailLayout.sleep,
      detailTitle: 'Sleep',
      categoryPillLabel: 'Sleep',
      categoryPillBackground: const Color(0xFFEEEDFE),
      categoryPillForeground: const Color(0xFF3C3489),
      categoryDotColor: AppColors.calPurple,
      dateLabel: dateLabel,
      startTime: '12:00',
      startSuffix: ' AM',
      endTime: '6:50',
      endSuffix: ' AM',
      durationCenter: '6h 50m',
      tasks: const [],
      wearablePhotoLabel: 'View 18 photos ▶',
      sourceAction: null,
    );
  }

  if (t.contains('platform') || t.contains('sprint') || t.contains('deep work')) {
    return ActivityDetailArgs(
      layout: ActivityDetailLayout.deepWork,
      detailTitle: 'Deep work — auth refactor',
      categoryPillLabel: 'Work',
      categoryPillBackground: const Color(0xFFE6F1FB),
      categoryPillForeground: const Color(0xFF0C447C),
      categoryDotColor: AppColors.calBlue,
      dateLabel: dateLabel,
      startTime: '8:30',
      startSuffix: ' AM',
      endTime: '11:15',
      endSuffix: ' AM',
      durationCenter: '2h 45m',
      tasks: const [
        LinkedTaskItem(
          title: 'Refactor token validation',
          subtitle: 'Platform › Auth · in progress',
          progress: LinkedTaskProgress.partialBlue,
        ),
        LinkedTaskItem(
          title: 'Review PR for auth flow',
          subtitle: 'Platform › Auth · done',
          progress: LinkedTaskProgress.doneGreen,
        ),
      ],
      wearablePhotoLabel: 'View 16 photos ▶',
      sourceAction: null,
    );
  }

  if (t.contains('run')) {
    return ActivityDetailArgs(
      layout: ActivityDetailLayout.deepWork,
      detailTitle: activity.title,
      categoryPillLabel: 'Exercise',
      categoryPillBackground: const Color(0xFFE8F8EF),
      categoryPillForeground: const Color(0xFF0F5132),
      categoryDotColor: AppColors.calGreen,
      dateLabel: dateLabel,
      startTime: '8:00',
      startSuffix: ' AM',
      endTime: '9:15',
      endSuffix: ' AM',
      durationCenter: activity.durationLabel,
      tasks: const [],
      wearablePhotoLabel: 'View 8 photos ▶',
      sourceAction: null,
    );
  }

  return ActivityDetailArgs(
    layout: ActivityDetailLayout.sleep,
    detailTitle: activity.title,
    categoryPillLabel: 'Action',
    categoryPillBackground: AppColors.slate100,
    categoryPillForeground: AppColors.slate600,
    categoryDotColor: AppColors.slate400,
    dateLabel: dateLabel,
    startTime: '—',
    startSuffix: '',
    endTime: '—',
    endSuffix: '',
    durationCenter: activity.durationLabel,
    tasks: const [],
    wearablePhotoLabel: 'View photos ▶',
    sourceAction: null,
  );
}

String _dateFromSnapshotTitle(String snapshotTitleLine) {
  final i = snapshotTitleLine.indexOf('—');
  if (i >= 0 && i + 1 < snapshotTitleLine.length) {
    return snapshotTitleLine.substring(i + 1).trim();
  }
  return snapshotTitleLine;
}

/// Builds the same detail args as Today, using an explicit calendar date line.
ActivityDetailArgs activityDetailArgsForCalendarRow({
  required String title,
  required String timeRangeLabel,
  required String durationLabel,
  required String dateLabel,
  required Color barColor,
}) {
  return activityDetailArgsForTodayRow(
    TodayActivity(
      title: title,
      timeRangeLabel: timeRangeLabel,
      durationLabel: durationLabel,
      barColor: barColor,
    ),
    'Today — $dateLabel',
  );
}
