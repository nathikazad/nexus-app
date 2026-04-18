import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:nx_time/app_theme.dart';
import 'package:nx_time/features/today/widgets/time_map_segment.dart';

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

  bool get _useFlexLayout =>
      segments.isNotEmpty && segments.every((s) => s.flex != null);

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
                  if (_useFlexLayout)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final seg in segments)
                          Expanded(
                            flex: seg.flex!,
                            child: ColoredBox(
                              color: _segmentPaintColor(seg.color),
                            ),
                          ),
                      ],
                    )
                  else
                    Stack(
                      fit: StackFit.expand,
                      children: [
                        const ColoredBox(color: AppColors.slate100),
                        for (final seg in segments)
                          if (seg.isPositioned)
                            Positioned(
                              left: barWidth * seg.startFraction!.clamp(0.0, 1.0),
                              width: math.max(
                                1,
                                barWidth * seg.widthFraction!.clamp(0.0, 1.0),
                              ),
                              top: 0,
                              bottom: 0,
                              child: ColoredBox(
                                color: _segmentPaintColor(seg.color)
                                    .withValues(alpha: 0.82),
                              ),
                            ),
                      ],
                    ),
                  Positioned(
                    left: barWidth * currentMarkerFraction.clamp(0.0, 1.0) - 1,
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
