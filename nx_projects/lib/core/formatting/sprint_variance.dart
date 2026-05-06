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

Color varianceColorForClass(BuildContext context, String? cls) {
  switch (cls) {
    case 'under':
      return context.colors.ok;
    case 'near':
      return context.colors.muted;
    case 'over':
      return context.colors.warn;
    case 'way-over':
      return context.colors.crit;
    default:
      return context.colors.muted;
  }
}

Color varianceColorForPair(BuildContext context, double actual, double est) {
  return varianceColorForClass(context, varianceClass(actual, est));
}

/// 2px high segmented progress matching `reference` `progVarianceSegments`.
class TaskProgressSegments extends StatelessWidget {
  TaskProgressSegments({
    super.key,
    required this.estimate,
    required this.actual,
    this.doneNoActual = false,
    this.actualColor,
  });

  final double estimate;
  final double actual;
  final bool doneNoActual;
  final Color? actualColor;

  @override
  Widget build(BuildContext context) {
    if (doneNoActual) {
      return _ProgressTrack(
        children: [Expanded(child: ColoredBox(color: context.colors.accent))],
      );
    }
    if (estimate <= 0 || actual <= 0) {
      return SizedBox.shrink();
    }
    final fillColor = actualColor ?? Color(0xFF4ADE80);
    final r = actual / estimate;
    final eps = 1e-9;
    if (r < 1 - eps) {
      return _ProgressTrack(
        children: [
          Expanded(
            flex: (r * 1000).round().clamp(1, 1000),
            child: ColoredBox(color: fillColor),
          ),
          Expanded(
            flex: ((1 - r) * 1000).round().clamp(1, 1000),
            child: SizedBox.shrink(),
          ),
        ],
      );
    }
    if (r <= 1 + eps) {
      return _ProgressTrack(
        children: [Expanded(child: ColoredBox(color: fillColor))],
      );
    }

    final base = (estimate / actual).clamp(0.0, 1.0);
    final overColor = r <= 1.5 ? context.colors.warn : context.colors.crit;
    return _ProgressTrack(
      children: [
        Expanded(
          flex: (base * 1000).round().clamp(1, 1000),
          child: ColoredBox(color: fillColor),
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
  _ProgressTrack({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(1),
      child: ColoredBox(
        color: Color(0xFF202736),
        child: SizedBox(height: 3, child: Row(children: children)),
      ),
    );
  }
}
