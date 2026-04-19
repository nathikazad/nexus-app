import 'package:flutter/material.dart';

/// Horizontal timeline with tick marks at [marks] and a draggable thumb at [value].
///
/// [value], [minTime], [maxTime], and each mark are **minutes since midnight** (fractional OK).
class TimelineSlider extends StatelessWidget {
  const TimelineSlider({
    super.key,
    required this.value,
    required this.minTime,
    required this.maxTime,
    required this.marks,
    required this.onChanged,
  });

  final double value;
  final double minTime;
  final double maxTime;
  final List<double> marks;
  final ValueChanged<double> onChanged;

  static double _valueToX(double v, double width, double min, double max) {
    final r = max - min;
    if (r <= 1e-9) return width / 2;
    return ((v - min) / r) * width;
  }

  static double _xToValue(double x, double width, double min, double max) {
    final r = max - min;
    if (r <= 1e-9) return min;
    final pct = (x / width).clamp(0.0, 1.0);
    return min + pct * r;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trackColor = theme.colorScheme.surfaceContainerHighest;
    final fillColor = theme.colorScheme.outline;
    final markColor = theme.colorScheme.onSurface;
    final thumbColor = theme.colorScheme.primary;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        return SizedBox(
          height: 28,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) {
              onChanged(_xToValue(d.localPosition.dx, w, minTime, maxTime));
            },
            onHorizontalDragUpdate: (d) {
              onChanged(_xToValue(d.localPosition.dx, w, minTime, maxTime));
            },
            child: CustomPaint(
              size: Size(w, 28),
              painter: _TimelinePainter(
                value: value,
                minTime: minTime,
                maxTime: maxTime,
                marks: marks,
                trackColor: trackColor,
                fillColor: fillColor,
                markColor: markColor,
                thumbColor: thumbColor,
                valueToX: (v) => _valueToX(v, w, minTime, maxTime),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TimelinePainter extends CustomPainter {
  _TimelinePainter({
    required this.value,
    required this.minTime,
    required this.maxTime,
    required this.marks,
    required this.trackColor,
    required this.fillColor,
    required this.markColor,
    required this.thumbColor,
    required this.valueToX,
  });

  final double value;
  final double minTime;
  final double maxTime;
  final List<double> marks;
  final Color trackColor;
  final Color fillColor;
  final Color markColor;
  final Color thumbColor;
  final double Function(double value) valueToX;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    const trackY = 12.0;
    const trackH = 4.0;

    // Background track
    final trackRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, trackY, w, trackH),
      const Radius.circular(2),
    );
    canvas.drawRRect(trackRect, Paint()..color = trackColor);

    // Filled portion to thumb
    final thumbX = valueToX(value).clamp(0.0, w);
    if (thumbX > 0) {
      final fillRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, trackY, thumbX, trackH),
        const Radius.circular(2),
      );
      canvas.drawRRect(fillRect, Paint()..color = fillColor);
    }

    // Tick marks
    final markPaint = Paint()
      ..color = markColor
      ..strokeWidth = 2;
    for (final m in marks) {
      if (m < minTime - 1e-6 || m > maxTime + 1e-6) continue;
      final x = valueToX(m).clamp(0.0, w);
      canvas.drawLine(
        Offset(x, 4),
        Offset(x, 14),
        markPaint,
      );
    }

    // Thumb
    final cx = valueToX(value).clamp(10.0, w - 10.0);
    canvas.drawCircle(
      Offset(cx, trackY + trackH / 2),
      10,
      Paint()..color = thumbColor,
    );
    canvas.drawCircle(
      Offset(cx, trackY + trackH / 2),
      10,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter oldDelegate) {
    if (value != oldDelegate.value ||
        minTime != oldDelegate.minTime ||
        maxTime != oldDelegate.maxTime ||
        trackColor != oldDelegate.trackColor ||
        marks.length != oldDelegate.marks.length) {
      return true;
    }
    for (var i = 0; i < marks.length; i++) {
      if (marks[i] != oldDelegate.marks[i]) return true;
    }
    return false;
  }
}
