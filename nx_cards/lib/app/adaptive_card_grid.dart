import 'package:flutter/material.dart';

/// Content-sized cards that gain columns as space permits, including in
/// split-screen windows. Text scaling increases the minimum readable width.
class AdaptiveCardGrid extends StatelessWidget {
  const AdaptiveCardGrid({
    super.key,
    required this.children,
    this.minimumCardWidth = 360,
    this.maxColumns = 3,
    this.spacing = 14,
  });

  final List<Widget> children;
  final double minimumCardWidth;
  final int maxColumns;
  final double spacing;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
      final minimum = minimumCardWidth * scale.clamp(1.0, 2.0);
      final columns = ((constraints.maxWidth + spacing) / (minimum + spacing))
          .floor()
          .clamp(1, maxColumns);
      final width = (constraints.maxWidth - spacing * (columns - 1)) / columns;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}
