import 'package:flutter/material.dart';
import 'package:nx_cards/app/theme.dart';

class CardMetric extends StatelessWidget {
  const CardMetric({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.stacked = false,
  });

  final IconData icon;
  final int value;
  final String label;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: RecallColors.muted),
              const SizedBox(width: 5),
              Text(
                '$value',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: RecallPalette.of(context).ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: RecallColors.faint),
          ),
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: RecallColors.muted),
        const SizedBox(width: 4),
        Text(
          '$value $label',
          style: const TextStyle(fontSize: 12, color: RecallColors.muted),
        ),
      ],
    );
  }
}
