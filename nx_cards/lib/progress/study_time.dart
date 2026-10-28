import 'package:nx_cards/browser/browser.dart';

DateTime _day(DateTime time) {
  final local = time.toLocal();
  return DateTime(local.year, local.month, local.day);
}

/// Estimated active recall time, not measured screen time. Multi-direction
/// reviews within one second count once; inherited phrase credits never count.
/// Gaps over five minutes start a session, other gaps contribute at most 90s.
/// The first question gets the day's median short gap (10–60s, default 30s).
/// Daily allowances keep estimates independent of chart grouping/date range.
Map<DateTime, Duration> estimatedStudyTime(
  List<StudyCard> cards, {
  required DateTime now,
  DateTime? start,
}) {
  final earliest = start?.subtract(const Duration(minutes: 5));
  final timestamps = <DateTime>{};
  for (final card in cards) {
    for (final reviews in card.reviewHistory.values) {
      for (final review in reviews) {
        if (!review.isPhraseCredit &&
            !review.reviewedAt.isAfter(now) &&
            (earliest == null || !review.reviewedAt.isBefore(earliest))) {
          timestamps.add(review.reviewedAt.toUtc());
        }
      }
    }
  }
  final ordered = timestamps.toList()..sort();
  final events = <DateTime>[];
  for (final time in ordered) {
    if (events.isEmpty || time.difference(events.last).inMilliseconds > 1000) {
      events.add(time);
    }
  }
  final gaps = <DateTime, List<int>>{};
  for (var i = 1; i < events.length; i++) {
    final gap = events[i].difference(events[i - 1]).inMilliseconds;
    if (gap > 1000 && gap <= 120000) {
      (gaps[_day(events[i])] ??= []).add(gap);
    }
  }
  final allowances = <DateTime, int>{};
  for (final entry in gaps.entries) {
    final values = entry.value..sort();
    final middle = values.length ~/ 2;
    final median = values.length.isOdd
        ? values[middle]
        : ((values[middle - 1] + values[middle]) / 2).round();
    allowances[entry.key] = median.clamp(10000, 60000);
  }
  final totals = <DateTime, Duration>{};
  for (var i = 0; i < events.length; i++) {
    final time = events[i];
    final gap = i == 0 ? null : time.difference(events[i - 1]).inMilliseconds;
    final millis = gap == null || gap > 300000
        ? allowances[_day(time)] ?? 30000
        : gap.clamp(0, 90000);
    var left = time.subtract(Duration(milliseconds: millis));
    if (start != null && left.isBefore(start)) left = start;
    while (left.isBefore(time)) {
      final day = _day(left);
      final midnight = DateTime(day.year, day.month, day.day + 1);
      final end = midnight.isBefore(time) ? midnight : time;
      totals[day] = (totals[day] ?? Duration.zero) + end.difference(left);
      left = end;
    }
  }
  return totals;
}

String formatStudyTime(Duration duration) {
  if (duration <= Duration.zero) return '0 min';
  if (duration.inSeconds < 60) return '<1 min';
  final minutes = (duration.inSeconds / 60).round();
  return minutes < 60
      ? '$minutes min'
      : '${minutes ~/ 60}h${minutes % 60 == 0 ? '' : ' ${minutes % 60}m'}';
}
