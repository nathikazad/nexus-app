import 'package:flutter/material.dart';

import 'package:nx_projects/core/theme/app_theme.dart';
import 'package:nx_projects/features/daily/daily_view_model.dart';

/// Stat chips row under `DdHead` (`reference/desktop` `.dd-stats`).
class DdStats extends StatelessWidget {
  DdStats({super.key, required this.stats});

  final DailyHeaderStats stats;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: [
        _StatChip(
          label: 'Done',
          value:
              '${stats.nDone} / ${stats.nTodo + stats.nDoing + stats.nBlocked + stats.nDone}',
          dot: context.colors.ok,
        ),
        _StatChip(label: 'Pushed', value: '0', isWarn: true),
        _StatChip(label: 'Rolled', value: '0'),
        _StatChip(
          label: 'Day hours',
          value: '${stats.totalEst.toStringAsFixed(0)}h planned',
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  _StatChip({
    required this.label,
    required this.value,
    this.dot,
    this.isWarn = false,
  });

  final String label;
  final String value;
  final Color? dot;
  final bool isWarn;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: context.colors.panel2,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot != null) ...[
            Container(
              width: 6,
              height: 6,
              margin: EdgeInsets.only(right: 6),
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
          ],
          Text(
            '$label  ',
            style: TextStyle(fontSize: 11, color: context.colors.muted),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isWarn ? context.colors.warn : context.colors.text,
            ),
          ),
        ],
      ),
    );
  }
}
