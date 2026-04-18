import 'package:flutter/material.dart';

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

  /// e.g. category path for current block
  final String? secondaryLine;

  /// Shown in orange pill when [kind] is current
  final String? liveElapsedLabel;
}
