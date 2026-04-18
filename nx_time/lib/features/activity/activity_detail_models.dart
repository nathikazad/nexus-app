import 'package:flutter/material.dart';

import '../../data/models/today_activity.dart';
import '../../theme/app_colors.dart';

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
  });

  final ActivityDetailLayout layout;
  final String detailTitle;
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

  int get linkedTaskCount => tasks.length;
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
    );
  }

  return ActivityDetailArgs(
    layout: ActivityDetailLayout.sleep,
    detailTitle: activity.title,
    categoryPillLabel: 'Activity',
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
