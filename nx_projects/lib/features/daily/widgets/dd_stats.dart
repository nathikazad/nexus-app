import 'package:flutter/material.dart';

import 'package:nx_projects/core/theme/app_theme.dart';
import 'package:nx_projects/features/daily/daily_view_model.dart';

/// Stat chips row under `DdHead` (`reference/desktop` `.dd-stats`).
class DdStats extends StatelessWidget {
  const DdStats({super.key, required this.stats});

  final DailyHeaderStats stats;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: [
        _StatChip(
          label: 'Done',
          value: '${stats.nDone} / ${stats.nTodo + stats.nDoing + stats.nBlocked + stats.nDone}',
          dot: AppColors.ok,
        ),
        _StatChip(
          label: 'Pushed',
          value: '0',
          isWarn: true,
        ),
        _StatChip(
          label: 'Rolled',
          value: '0',
        ),
        _StatChip(
          label: 'Day hours',
          value: '${stats.totalEst.toStringAsFixed(0)}h planned',
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.panel2,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot != null) ...[
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
          ],
          Text(
            '$label  ',
            style: const TextStyle(fontSize: 11, color: AppColors.muted),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isWarn ? AppColors.warn : AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}
