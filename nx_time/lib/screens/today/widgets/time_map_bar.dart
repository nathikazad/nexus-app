import 'package:flutter/material.dart';

import '../../../data/models/time_map_segment.dart';
import '../../../app_theme.dart';

/// Horizontal day timeline bar + current-time marker (see `tab-today.html`).
Color _segmentPaintColor(Color c) {
  if (c == Colors.transparent) {
    return AppColors.slate100;
  }
  return c;
}

class TimeMapBar extends StatelessWidget {
  const TimeMapBar({
    super.key,
    required this.segments,
    required this.currentMarkerFraction,
  });

  final List<TimeMapSegment> segments;
  final double currentMarkerFraction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        height: 36,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final barWidth = constraints.maxWidth;
            return ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final seg in segments)
                        Expanded(
                          flex: seg.flex,
                          child: ColoredBox(
                            color: _segmentPaintColor(seg.color),
                          ),
                        ),
                    ],
                  ),
                  Positioned(
                    left: barWidth * currentMarkerFraction - 1,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 2,
                      decoration: const BoxDecoration(
                        color: AppColors.slate900,
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 2,
                            offset: Offset(0, 1),
                            color: Color(0x33000000),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
