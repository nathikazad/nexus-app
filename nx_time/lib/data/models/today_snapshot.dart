import 'activity_category.dart';
import 'time_map_segment.dart';
import 'today_activity.dart';

class TodaySnapshot {
  const TodaySnapshot({
    required this.clockLabel,
    required this.titleLine,
    required this.timeMapSegments,
    required this.currentMarkerFraction,
    required this.legend,
    required this.activityBlockCount,
    required this.actions,
  });

  final String clockLabel;
  final String titleLine;
  final List<TimeMapSegment> timeMapSegments;

  /// 0–1, horizontal position of “now” line on the bar.
  final double currentMarkerFraction;
  final List<ActivityCategory> legend;
  final int activityBlockCount;
  final List<TodayActivity> actions;
}
