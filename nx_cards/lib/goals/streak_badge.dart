import 'package:flutter/material.dart';

const streakAccent = Color(0xFFB67B63);

/// Vector artwork keeps the flame crisp at every density without a font asset.
class StreakBadge extends StatelessWidget {
  const StreakBadge({super.key, required this.days});
  final int days;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: '$days-day streak of meeting your daily goal',
      child: Semantics(
        label: '$days-day daily goal streak',
        child: ExcludeSemantics(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 22,
                height: 28,
                child: CustomPaint(painter: _FlamePainter()),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  '$days-day streak',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FlamePainter extends CustomPainter {
  const _FlamePainter();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 36, size.height / 44);
    // Compact, rounded silhouette matches the page's bold utility icons.
    final outline = Path()
      ..moveTo(19, 5)
      ..cubicTo(20, 13, 28, 17, 28, 26)
      ..cubicTo(28, 33, 24, 38, 18, 38)
      ..cubicTo(11, 38, 7, 33, 7, 27)
      ..cubicTo(7, 22, 10, 18, 13, 15)
      ..cubicTo(13, 20, 15, 22, 17, 23)
      ..cubicTo(20, 18, 21, 12, 19, 5)
      ..close();
    canvas.drawPath(outline, Paint()..color = streakAccent);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FlamePainter oldDelegate) => false;
}
