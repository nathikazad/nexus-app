import 'models/activity_category.dart';
import 'models/time_map_segment.dart';
import 'models/today_activity.dart';
import 'models/today_snapshot.dart';
import 'today_repository_interface.dart';
import '../theme/app_colors.dart';

/// In-memory fake backend for the Today screen (no GraphQL).
class FakeTodayRepository implements TodayRepository {
  @override
  Future<TodaySnapshot> loadToday([DateTime? forDay]) async => buildSnapshot();

  /// Synchronous snapshot for tests and callers that need immediate data.
  TodaySnapshot buildSnapshot() {
    return TodaySnapshot(
      clockLabel: '9:41 AM',
      titleLine: 'Today — Thu, Oct 26',
      timeMapSegments: const [
        TimeMapSegment(color: AppColors.sleepBlue, flex: 32),
        TimeMapSegment(color: AppColors.routineGray, flex: 5),
        TimeMapSegment(color: AppColors.exerciseGreen, flex: 8),
        TimeMapSegment(color: AppColors.routineGray, flex: 5),
        TimeMapSegment(color: AppColors.accent, flex: 25),
        TimeMapSegment(color: AppColors.slate100, flex: 25),
      ],
      currentMarkerFraction: 0.75,
      legend: const [
        ActivityCategory(label: 'Sleep', swatch: AppColors.sleepBlue),
        ActivityCategory(label: 'Work', swatch: AppColors.accent),
        ActivityCategory(label: 'Exercise', swatch: AppColors.exerciseGreen),
        ActivityCategory(label: 'Eat/Cook', swatch: AppColors.eatYellow),
        ActivityCategory(label: 'Outdoors', swatch: AppColors.outdoorsTeal),
        ActivityCategory(label: 'Routine', swatch: AppColors.routineGray),
      ],
      activityBlockCount: 12,
      actions: const [
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
      ],
    );
  }
}
