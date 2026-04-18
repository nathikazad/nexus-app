import 'package:flutter/material.dart';

/// One colored slice of the day bar; [flex] is proportional width (sum need not be 100).
class TimeMapSegment {
  const TimeMapSegment({
    required this.color,
    required this.flex,
  });

  final Color color;
  final int flex;
}
