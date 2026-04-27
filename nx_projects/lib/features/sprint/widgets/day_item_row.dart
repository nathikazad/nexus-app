import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:nx_projects/core/formatting/date_label.dart';
import 'package:nx_projects/core/formatting/hours_format.dart';
import 'package:nx_projects/core/formatting/sprint_variance.dart';
import 'package:nx_projects/core/theme/app_theme.dart';
import 'package:nx_projects/core/theme/kind_color_palette.dart';
import 'package:nx_projects/domain/task/task.dart';
import 'package:nx_projects/domain/task/task_kind.dart';
import 'package:nx_projects/domain/task/task_status.dart';

/// Dense row for a task on a desktop sprint day (draggable to another day when [enableDrag]).
class DayItemRow extends StatefulWidget {
  const DayItemRow({
    super.key,
    required this.task,
    this.onMenu,
    this.isGhost = false,
    this.movedToYmd,
    this.enableDrag = true,
  });

  final Task task;
  final VoidCallback? onMenu;
  final bool isGhost;
  final String? movedToYmd;
  final bool enableDrag;

  @override
  State<DayItemRow> createState() => _DayItemRowState();
}

class _DayItemRowState extends State<DayItemRow> {
  bool _h = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.task;
    final done = t.status == TaskStatus.done;
    final blocked = t.status == TaskStatus.blocked;
    var glyph = '▢';
    if (t.kind == TaskKind.bug) {
      glyph = '●';
    } else if (t.kind == TaskKind.feat) {
      glyph = '◉';
    }
    if (widget.isGhost) {
      return _ghostRow(t, glyph, done);
    }
    Widget buildMain() {
      return _mainRow(t: t, done: done, blocked: blocked, glyph: glyph);
    }

    if (widget.enableDrag) {
      return Draggable<Task>(
        data: t,
        maxSimultaneousDrags: 1,
        feedback: _dragFeedback(t, done, glyph),
        childWhenDragging: Opacity(opacity: 0.4, child: buildMain()),
        child: buildMain(),
      );
    }
    return buildMain();
  }

  String _movedToLabel() {
    final y = widget.movedToYmd;
    if (y == null) return '';
    final d = parseLocalDate(y);
    return '→ moved to ${DateFormat('EEE MMM d').format(d)}';
  }

  Widget _ghostRow(Task t, String glyph, bool done) {
    return Opacity(
      opacity: 0.55,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: AppColors.border2, width: 1),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            const SizedBox(width: 7),
            const SizedBox(width: 7),
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
                '${t.title}  ${_movedToLabel()}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Material _dragFeedback(Task t, bool done, String glyph) {
    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: _mainRow(
          t: t,
          done: done,
          blocked: t.status == TaskStatus.blocked,
          glyph: glyph,
        ),
      ),
    );
  }

  Widget _mainRow({
    required Task t,
    required bool done,
    required bool blocked,
    required String glyph,
  }) {
    final doneNoActual = done && t.actualHours <= 0;
    final actualForProgress = doneNoActual ? t.estimate : t.actualHours;
    return MouseRegion(
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: Material(
        color: _h ? AppColors.panel3 : AppColors.panel2,
        borderRadius: BorderRadius.circular(5),
        child: InkWell(
          onTap: widget.onMenu,
          borderRadius: BorderRadius.circular(5),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              border: blocked
                  ? Border.all(color: const Color(0x40FF6B6B), width: 1)
                  : null,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StatusDot(status: t.status),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: SizedBox(
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
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        t.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: done ? AppColors.muted : AppColors.text,
                          decoration: done ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      if (t.estimate > 0 && actualForProgress > 0) ...[
                        const SizedBox(height: 4),
                        TaskProgressSegments(
                          estimate: t.estimate,
                          actual: actualForProgress,
                          doneNoActual: doneNoActual,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(width: 66, child: _HoursCell(task: t)),
                const SizedBox(width: 4),
                SizedBox(
                  width: 16,
                  child: InkWell(
                    onTap: widget.onMenu,
                    child: const Text(
                      '⋮',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.dim,
                        height: 1,
                      ),
                    ),
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
      margin: const EdgeInsets.only(top: 5),
      decoration: BoxDecoration(
        color: c,
        shape: BoxShape.circle,
        boxShadow: status == TaskStatus.doing
            ? [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.25),
                  blurRadius: 0,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
    );
  }
}

class _HoursCell extends StatelessWidget {
  const _HoursCell({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    if (task.actualHours <= 0) {
      return Text(
        formatHours(task.estimate),
        textAlign: TextAlign.right,
        style: const TextStyle(
          fontSize: 11,
          color: AppColors.muted,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      );
    }

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: formatHours(task.actualHours),
            style: TextStyle(
              color: varianceColorForPair(task.actualHours, task.estimate),
              fontWeight: FontWeight.w500,
            ),
          ),
          TextSpan(
            text: ' / ${formatHours(task.estimate)}',
            style: const TextStyle(color: AppColors.dim),
          ),
        ],
      ),
      textAlign: TextAlign.right,
      style: const TextStyle(
        fontSize: 11,
        color: AppColors.muted,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
    );
  }
}
