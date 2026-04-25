import 'package:flutter/material.dart';

import 'package:nx_projects/core/formatting/hours_format.dart';
import 'package:nx_projects/core/theme/app_theme.dart';
import 'package:nx_projects/core/theme/kind_color_palette.dart';
import 'package:nx_projects/domain/task/task.dart';
import 'package:nx_projects/domain/task/task_kind.dart';
import 'package:nx_projects/domain/task/task_status.dart';

/// One task card in desktop daily left column (`reference/desktop` `.dd-task` simplified).
class DdTaskRow extends StatelessWidget {
  const DdTaskRow({super.key, required this.task, this.onMenu});

  final Task task;
  final VoidCallback? onMenu;

  @override
  Widget build(BuildContext context) {
    final t = task;
    final done = t.status == TaskStatus.done;
    String glyph;
    if (t.kind == TaskKind.bug) {
      glyph = '●';
    } else if (t.kind == TaskKind.feat) {
      glyph = '◉';
    } else {
      glyph = '▢';
    }
    return Material(
      color: AppColors.panel,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onMenu,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StatusDot(status: t.status),
              const SizedBox(width: 10),
              Text(
                glyph,
                style: TextStyle(
                  fontSize: 16,
                  color: done ? AppColors.dim : kindColor(t.kind),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          if (t.crumb.isNotEmpty)
                            TextSpan(
                              text: '${t.crumb}  ',
                              style: const TextStyle(fontSize: 10, color: AppColors.dim),
                            ),
                          TextSpan(
                            text: t.title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: done ? AppColors.muted : AppColors.text,
                              decoration: done ? TextDecoration.lineThrough : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatHours(t.estimate),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status});

  final TaskStatus status;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          color: _dotColor(status),
          shape: BoxShape.circle,
          boxShadow: status == TaskStatus.doing
              ? [BoxShadow(color: AppColors.accent.withValues(alpha: 0.3), spreadRadius: 2)]
              : null,
        ),
      ),
    );
  }

  Color _dotColor(TaskStatus s) {
    return switch (s) {
      TaskStatus.todo => AppColors.dim,
      TaskStatus.doing => AppColors.accent,
      TaskStatus.done => AppColors.ok,
      TaskStatus.blocked => AppColors.crit,
    };
  }
}
