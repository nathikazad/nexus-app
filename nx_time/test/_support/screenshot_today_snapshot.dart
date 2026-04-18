import 'package:nx_time/core/theme/app_theme.dart';
import 'package:nx_time/domain/action/action.dart';
import 'package:nx_time/features/today/today_view_model.dart';
import 'package:nx_time/features/today/widgets/time_map_segment.dart';

/// Fixed snapshot for golden/screenshot tests (no network).
TodaySnapshot buildScreenshotTodaySnapshot() {
  const actions = [
    TodayActivity(
      title: 'Deep sleep',
      timeRangeLabel: '11:30p – 7:15a',
      durationLabel: '7h 45m',
      barColor: AppColors.sleepBlue,
    ),
    TodayActivity(
      title: 'Morning prep',
      timeRangeLabel: '7:15a – 8:00a',
      durationLabel: '45m',
      barColor: AppColors.routineGray,
    ),
    TodayActivity(
      title: 'Morning Run',
      timeRangeLabel: '8:00a – 9:15a',
      durationLabel: '1h 15m',
      barColor: AppColors.exerciseGreen,
      kind: TodayActivityKind.flagged,
    ),
    TodayActivity(
      title: 'Platform › Sprint review',
      timeRangeLabel: '9:45a – now',
      durationLabel: '00:32:14',
      barColor: AppColors.accent,
      kind: TodayActivityKind.current,
      liveElapsedLabel: '00:32:14',
    ),
  ];

  const sourceActions = [
    Action(id: 1, name: 'Deep sleep', modelTypeId: 1, modelTypeName: 'Sleep'),
    Action(id: 2, name: 'Morning prep', modelTypeId: 2, modelTypeName: 'Routine'),
    Action(id: 3, name: 'Morning Run', modelTypeId: 3, modelTypeName: 'Workout'),
    Action(id: 4, name: 'Platform › Sprint review', modelTypeId: 4, modelTypeName: 'Meet'),
  ];

  return const TodaySnapshot(
    clockLabel: '9:41 AM',
    titleLine: 'Today — Thu, Oct 26',
    timeMapSegments: [
      TimeMapSegment(color: AppColors.sleepBlue, flex: 32),
      TimeMapSegment(color: AppColors.routineGray, flex: 5),
      TimeMapSegment(color: AppColors.exerciseGreen, flex: 8),
      TimeMapSegment(color: AppColors.routineGray, flex: 5),
      TimeMapSegment(color: AppColors.accent, flex: 25),
      TimeMapSegment(color: AppColors.slate100, flex: 25),
    ],
    currentMarkerFraction: 0.75,
    legend: [
      ActivityCategory(label: 'Sleep', swatch: AppColors.sleepBlue),
      ActivityCategory(label: 'Work', swatch: AppColors.accent),
      ActivityCategory(label: 'Exercise', swatch: AppColors.exerciseGreen),
      ActivityCategory(label: 'Eat/Cook', swatch: AppColors.eatYellow),
      ActivityCategory(label: 'Outdoors', swatch: AppColors.outdoorsTeal),
      ActivityCategory(label: 'Routine', swatch: AppColors.routineGray),
    ],
    activityBlockCount: 12,
    actions: actions,
    sourceActions: sourceActions,
  );
}
