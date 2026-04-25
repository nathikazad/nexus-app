import 'package:flutter/material.dart';

import 'package:nx_projects/core/theme/app_theme.dart';

/// Aligned with `reference/desktop/index.html` `varianceCls` bands.
String varianceClass(double actual, double est) {
  if (est <= 0) {
    if (actual > 0) return 'way-over';
    return '';
  }
  final r = actual / est;
  if (r < 0.85) return 'under';
  if (r < 1.1) return 'near';
  if (r < 1.35) return 'over';
  return 'way-over';
}

Color varianceColorForClass(String? cls) {
  switch (cls) {
    case 'under':
      return AppColors.ok;
    case 'near':
      return AppColors.muted;
    case 'over':
      return AppColors.warn;
    case 'way-over':
      return AppColors.crit;
    default:
      return AppColors.muted;
  }
}

Color varianceColorForPair(double actual, double est) {
  return varianceColorForClass(varianceClass(actual, est));
}

/// 3px high segmented track (under / near / over / way-over), filled from the left
/// up to [actual/estimate] of a 0–1.5× range (capped) — `reference` `.prog`.
class TaskProgressSegments extends StatelessWidget {
  const TaskProgressSegments({super.key, required this.estimate, required this.actual});

  final double estimate;
  final double actual;

  @override
  Widget build(BuildContext context) {
    if (estimate <= 0 && actual <= 0) {
      return const SizedBox.shrink();
    }
    final r = estimate > 0 ? (actual / estimate).clamp(0, 2.0) : 2.0;
    if (r <= 0) {
      return const SizedBox.shrink();
    }
    final p = (r / 1.5).clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        return ClipRRect(
          borderRadius: BorderRadius.circular(1),
          child: SizedBox(
            height: 3,
            child: Stack(
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 85,
                      child: ColoredBox(color: const Color(0x804ADE80)),
                    ),
                    const SizedBox(width: 1),
                    Expanded(
                      flex: 25,
                      child: ColoredBox(color: const Color(0x338A93A6)),
                    ),
                    const SizedBox(width: 1),
                    Expanded(
                      flex: 25,
                      child: ColoredBox(color: const Color(0x40FBBF24)),
                    ),
                    const SizedBox(width: 1),
                    Expanded(
                      flex: 65,
                      child: ColoredBox(color: const Color(0x40F87171)),
                    ),
                  ],
                ),
                if (p < 1)
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    child: ColoredBox(
                      color: AppColors.panel2,
                      child: SizedBox(width: w * (1 - p)),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
