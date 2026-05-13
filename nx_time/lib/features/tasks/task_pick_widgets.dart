import 'package:flutter/material.dart';
import 'package:solar_icon_pack/solar_icon_pack.dart';

import 'package:nx_time/core/theme/app_theme.dart';

/// Square checkbox used on task picker & project drill screens (reference HTML).
class TaskSquareCheck extends StatelessWidget {
  const TaskSquareCheck({super.key, required this.selected, this.onTap});

  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final box = SizedBox(
      width: 22,
      height: 22,
      child: selected
          ? DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                SolarLinearIcons.checkRead,
                size: 14,
                color: Colors.white,
              ),
            )
          : Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.slate300, width: 1.5),
              ),
            ),
    );
    if (onTap == null) return box;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: box,
    );
  }
}

/// Bottom bar: N selected, + New task, Done (orange).
class TaskPickFooter extends StatelessWidget {
  const TaskPickFooter({
    super.key,
    required this.selectedLabel,
    required this.onDone,
    this.onNewTask,
  });

  final String selectedLabel;
  final VoidCallback onDone;
  final VoidCallback? onNewTask;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Material(
      color: Colors.white.withValues(alpha: 0.95),
      child: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.slate100)),
        ),
        padding: EdgeInsets.fromLTRB(16, 12, 16, bottom + 12),
        child: Row(
          children: [
            Text(
              selectedLabel,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.slate900,
              ),
            ),
            const Spacer(),
            OutlinedButton(
              onPressed: onNewTask,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.slate700,
                side: const BorderSide(color: AppColors.slate200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                '+ New task',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: onDone,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Done',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
