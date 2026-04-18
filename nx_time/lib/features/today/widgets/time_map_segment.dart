import 'package:flutter/material.dart';

/// One slice of the day bar.
///
/// **Flex layout** (mock / fake data): [flex] is proportional width in a [Row].
/// **Positioned layout** (real data): [startFraction] and [widthFraction] are
/// fractions of the local calendar day `[0, 1)`; overlapping blocks stack in order.
class TimeMapSegment {
  const TimeMapSegment({
    required this.color,
    required this.flex,
  })  : startFraction = null,
        widthFraction = null;

  const TimeMapSegment.positioned({
    required this.color,
    required this.startFraction,
    required this.widthFraction,
  }) : flex = null;

  final Color color;
  final int? flex;
  final double? startFraction;
  final double? widthFraction;

  bool get isPositioned => flex == null;
}
