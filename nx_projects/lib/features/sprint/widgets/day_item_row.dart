import 'package:flutter/material.dart';

import 'package:nx_projects/core/formatting/hours_format.dart';
import 'package:nx_projects/core/theme/app_theme.dart';
import 'package:nx_projects/core/theme/kind_color_palette.dart';
import 'package:nx_projects/domain/task/task.dart';
import 'package:nx_projects/domain/task/task_kind.dart';
import 'package:nx_projects/domain/task/task_status.dart';

/// Dense row for a task on a desktop sprint day (drag-and-drop is not implemented yet).
class DayItemRow extends StatefulWidget {
  const DayItemRow({
    super.key,
    required this.task,
    this.onMenu,
  });

  final Task task;
  final VoidCallback? onMenu;

  @override
  State<DayItemRow> createState() => _DayItemRowState();
}

class _DayItemRowState extends State<DayItemRow> {
  bool _h = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.task;
    final done = t.status == TaskStatus.done;
    String glyph;
    if (t.kind == TaskKind.bug) {
      glyph = '●';
    } else if (t.kind == TaskKind.feat) {
      glyph = '◉';
    } else {
      glyph = '▢';
    }
    return MouseRegion(
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: Material(
        color: _h ? AppColors.panel2 : AppColors.panel2,
        borderRadius: BorderRadius.circular(5),
        child: InkWell(
          onTap: widget.onMenu,
          borderRadius: BorderRadius.circular(5),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                _StatusDot(status: t.status),
                const SizedBox(width: 8),
                SizedBox(
                  width: 14,
                  child: Text(
                    glyph,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: done ? AppColors.dim : kindColor(t.kind),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    t.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: done ? AppColors.muted : AppColors.text,
                      decoration: done ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  formatHours(t.estimate),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.muted,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: widget.onMenu,
                  child: const Text(
                    '⋮',
                    style: TextStyle(fontSize: 14, color: AppColors.dim, height: 1),
                  ),
                ),
              ],
            ),
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
    Color c;
    switch (status) {
      case TaskStatus.todo:
        c = AppColors.dim;
        break;
      case TaskStatus.doing:
        c = AppColors.accent;
        break;
      case TaskStatus.done:
        c = AppColors.ok;
        break;
      case TaskStatus.blocked:
        c = AppColors.crit;
        break;
    }
    return Container(
      width: 7,
      height: 7,
      margin: const EdgeInsets.only(top: 2),
      decoration: BoxDecoration(
        color: c,
        shape: BoxShape.circle,
        boxShadow: status == TaskStatus.doing
            ? [BoxShadow(color: AppColors.accent.withValues(alpha: 0.25), blurRadius: 0, spreadRadius: 2)]
            : null,
      ),
    );
  }
}
