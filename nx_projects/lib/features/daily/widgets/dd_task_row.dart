import 'package:flutter/material.dart';

import 'package:nx_projects/core/formatting/hours_format.dart';
import 'package:nx_projects/core/theme/app_theme.dart';
import 'package:nx_projects/core/theme/kind_color_palette.dart';
import 'package:nx_projects/domain/task/task.dart';
import 'package:nx_projects/domain/task/task_kind.dart';
import 'package:nx_projects/domain/task/task_status.dart';

/// One task card in desktop daily left column (`reference/desktop` `.dd-task` simplified).
class DdTaskRow extends StatelessWidget {
  DdTaskRow({super.key, required this.task, this.onTap, this.onMenu});

  final Task task;
  final VoidCallback? onTap;
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
      color: context.colors.panel,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        onSecondaryTap: onMenu,
        onLongPress: onMenu,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: context.colors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StatusDot(status: t.status),
              SizedBox(width: 10),
              Text(
                glyph,
                style: TextStyle(
                  fontSize: 16,
                  color: done ? context.colors.dim : kindColor(context, t.kind),
                ),
              ),
              SizedBox(width: 10),
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
                              style: TextStyle(
                                fontSize: 10,
                                color: context.colors.dim,
                              ),
                            ),
                          TextSpan(
                            text: t.title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: done
                                  ? context.colors.muted
                                  : context.colors.text,
                              decoration: done
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              Text(
                formatHours(t.estimate),
                style: TextStyle(fontSize: 12, color: context.colors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  _StatusDot({required this.status});

  final TaskStatus status;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 6),
      child: Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          color: _dotColor(context, status),
          shape: BoxShape.circle,
          boxShadow: status == TaskStatus.doing
              ? [
                  BoxShadow(
                    color: context.colors.accent.withValues(alpha: 0.3),
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
      ),
    );
  }

  Color _dotColor(BuildContext context, TaskStatus s) {
    return switch (s) {
      TaskStatus.todo => context.colors.dim,
      TaskStatus.doing => context.colors.accent,
      TaskStatus.done => context.colors.ok,
      TaskStatus.blocked => context.colors.crit,
    };
  }
}
