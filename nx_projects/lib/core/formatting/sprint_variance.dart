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

/// 2px high segmented progress matching `reference` `progVarianceSegments`.
class TaskProgressSegments extends StatelessWidget {
  const TaskProgressSegments({
    super.key,
    required this.estimate,
    required this.actual,
    this.doneNoActual = false,
  });

  final double estimate;
  final double actual;
  final bool doneNoActual;

  @override
  Widget build(BuildContext context) {
    if (doneNoActual) {
      return const _ProgressTrack(
        children: [Expanded(child: ColoredBox(color: AppColors.accent))],
      );
    }
    if (estimate <= 0 || actual <= 0) {
      return const SizedBox.shrink();
    }
    final r = actual / estimate;
    const eps = 1e-9;
    if (r < 1 - eps) {
      return _ProgressTrack(
        children: [
          Expanded(
            flex: (r * 1000).round().clamp(1, 1000),
            child: const ColoredBox(color: Color(0xFF4ADE80)),
          ),
          Expanded(
            flex: ((1 - r) * 1000).round().clamp(1, 1000),
            child: const SizedBox.shrink(),
          ),
        ],
      );
    }
    if (r <= 1 + eps) {
      return const _ProgressTrack(
        children: [Expanded(child: ColoredBox(color: AppColors.accent))],
      );
    }

    final base = (estimate / actual).clamp(0.0, 1.0);
    final overColor = r <= 1.5 ? AppColors.warn : AppColors.crit;
    return _ProgressTrack(
      children: [
        Expanded(
          flex: (base * 1000).round().clamp(1, 1000),
          child: const ColoredBox(color: AppColors.accent),
        ),
        Expanded(
          flex: ((1 - base) * 1000).round().clamp(1, 1000),
          child: ColoredBox(color: overColor),
        ),
      ],
    );
  }
}

class _ProgressTrack extends StatelessWidget {
  const _ProgressTrack({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(1),
      child: ColoredBox(
        color: const Color(0xFF202736),
        child: SizedBox(height: 3, child: Row(children: children)),
      ),
    );
  }
}
