import 'package:flutter/material.dart';

import '../../../data/models/time_map_segment.dart';
import '../../../theme/app_colors.dart';

class TimeMapBar extends StatelessWidget {
  const TimeMapBar({
    super.key,
    required this.segments,
    required this.currentMarkerFraction,
    this.onWeekViewTap,
  });

  final List<TimeMapSegment> segments;
  final double currentMarkerFraction;
  final VoidCallback? onWeekViewTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: onWeekViewTap,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: AppColors.slate500,
            ),
            child: const Text(
              'week view ↗',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        LayoutBuilder(
          builder: (context, constraints) {
            final barWidth = constraints.maxWidth;
            return ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: SizedBox(
                height: 36,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ColoredBox(
                      color: AppColors.slate100,
                      child: Row(
                        children: [
                          for (final seg in segments)
                            Expanded(
                              flex: seg.flex,
                              child: ColoredBox(color: seg.color),
                            ),
                        ],
                      ),
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
              ),
            );
          },
        ),
      ],
    );
  }
}
