import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:nx_projects/core/formatting/date_label.dart';
import 'package:nx_projects/core/formatting/hours_format.dart';
import 'package:nx_projects/core/formatting/sprint_variance.dart';
import 'package:nx_projects/core/theme/app_theme.dart';
import 'package:nx_projects/domain/task/task.dart';
import 'package:nx_projects/domain/task/task_status.dart';

/// Dense row for a task on a desktop sprint day (draggable to another day when [enableDrag]).
class DayItemRow extends StatefulWidget {
  DayItemRow({
    super.key,
    required this.task,
    this.onMenu,
    this.onTap,
    this.isGhost = false,
    this.movedToYmd,
    this.actualHours,
    this.priorActualHours = 0,
    this.actionCount,
    this.workLinks = const <TaskWorkLink>[],
    this.barColor,
    this.enableDrag = true,
    this.isLocated = false,
  });

  final Task task;
  final VoidCallback? onMenu;
  final VoidCallback? onTap;
  final bool isGhost;
  final String? movedToYmd;
  final double? actualHours;
  final double priorActualHours;
  final int? actionCount;
  final List<TaskWorkLink> workLinks;
  final Color? barColor;
  final bool enableDrag;
  final bool isLocated;

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
    if (widget.isGhost) {
      return _ghostRow(t, done);
    }
    Widget buildMain() {
      return _mainRow(t: t, done: done, blocked: blocked);
    }

    if (widget.enableDrag) {
      return Draggable<Task>(
        data: t,
        maxSimultaneousDrags: 1,
        feedback: _dragFeedback(t, done),
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

  Widget _ghostRow(Task t, bool done) {
    return Opacity(
      opacity: 0.55,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: context.colors.border2, width: 1),
        ),
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            _ProjectDot(color: widget.barColor ?? context.colors.dim),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                '${t.title}  ${_movedToLabel()}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: context.colors.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Material _dragFeedback(Task t, bool done) {
    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 400),
        child: _mainRow(
          t: t,
          done: done,
          blocked: t.status == TaskStatus.blocked,
        ),
      ),
    );
  }

  Widget _mainRow({
    required Task t,
    required bool done,
    required bool blocked,
  }) {
    final actualHours = widget.actualHours ?? t.actualHours;
    final priorActualHours = widget.priorActualHours;
    final cumulativeActualHours = priorActualHours + actualHours;
    final doneNoActual = widget.actualHours == null && done && actualHours <= 0;
    final actualForProgress = doneNoActual ? t.estimate : cumulativeActualHours;
    final projectColor = widget.barColor ?? context.colors.dim;
    final workMessages = _workDescriptions();
    return MouseRegion(
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: Material(
        color: _h ? context.colors.panel3 : context.colors.panel2,
        borderRadius: BorderRadius.circular(5),
        child: InkWell(
          onTap: widget.onTap ?? widget.onMenu,
          borderRadius: BorderRadius.circular(5),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: widget.isLocated ? Color(0x10FBBF24) : null,
              borderRadius: BorderRadius.circular(5),
              border: widget.isLocated
                  ? Border.all(color: Color(0x59FBBF24), width: 1)
                  : blocked
                  ? Border.all(color: Color(0x40FF6B6B), width: 1)
                  : null,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ProjectDot(color: projectColor),
                SizedBox(width: 6),
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
                          color: done
                              ? context.colors.muted
                              : context.colors.text,
                          decoration: done ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      if (t.estimate > 0 && actualForProgress > 0) ...[
                        SizedBox(height: 4),
                        _CumulativeTaskBar(
                          priorHours: priorActualHours,
                          dayHours: actualHours,
                          estimateHours: t.estimate,
                          dayColor: projectColor,
                          height: 3,
                        ),
                      ],
                      if (widget.actionCount != null &&
                          widget.actionCount! > 1) ...[
                        SizedBox(height: 3),
                        Text(
                          '${widget.actionCount} Work actions',
                          style: TextStyle(
                            fontSize: 10,
                            color: context.colors.dim,
                          ),
                        ),
                      ],
                      if (workMessages.isNotEmpty) ...[
                        SizedBox(height: 4),
                        for (final message in workMessages)
                          Padding(
                            padding: EdgeInsets.only(bottom: 2),
                            child: Text(
                              message,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                color: context.colors.muted,
                                height: 1.25,
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: 6),
                SizedBox(
                  width: 66,
                  child: _HoursCell(
                    task: t,
                    actualHours: cumulativeActualHours,
                  ),
                ),
                SizedBox(width: 4),
                SizedBox(
                  width: 16,
                  child: InkWell(
                    onTap: widget.onMenu == null
                        ? null
                        : () {
                            widget.onMenu!();
                          },
                    child: Text(
                      '⋮',
                      style: TextStyle(
                        fontSize: 14,
                        color: context.colors.dim,
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

  List<String> _workDescriptions() {
    return [
      for (final link in widget.workLinks)
        if (link.workDescription.trim().isNotEmpty) link.workDescription.trim(),
    ];
  }
}

class _CumulativeTaskBar extends StatelessWidget {
  _CumulativeTaskBar({
    required this.priorHours,
    required this.dayHours,
    required this.estimateHours,
    required this.dayColor,
    required this.height,
  });

  final double priorHours;
  final double dayHours;
  final double estimateHours;
  final Color dayColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (estimateHours <= 0) return SizedBox(height: height);
    final priorRatio = (priorHours / estimateHours).clamp(0.0, 1.0);
    final dayRatio = (dayHours / estimateHours).clamp(0.0, 1.0 - priorRatio);
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        height: height,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return Stack(
              children: [
                ColoredBox(
                  color: context.colors.panel3,
                  child: SizedBox.expand(),
                ),
                if (priorRatio > 0)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: width * priorRatio,
                    child: ColoredBox(color: context.colors.border2),
                  ),
                if (dayRatio > 0)
                  Positioned(
                    left: width * priorRatio,
                    top: 0,
                    bottom: 0,
                    width: width * dayRatio,
                    child: ColoredBox(color: dayColor),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ProjectDot extends StatelessWidget {
  _ProjectDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 9,
      height: 9,
      margin: EdgeInsets.only(top: 4),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _HoursCell extends StatelessWidget {
  _HoursCell({required this.task, required this.actualHours});

  final Task task;
  final double actualHours;

  @override
  Widget build(BuildContext context) {
    if (actualHours <= 0) {
      return Text(
        formatHours(task.estimate),
        textAlign: TextAlign.right,
        style: TextStyle(
          fontSize: 11,
          color: context.colors.muted,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      );
    }

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: formatHours(actualHours),
            style: TextStyle(
              color: varianceColorForPair(context, actualHours, task.estimate),
              fontWeight: FontWeight.w500,
            ),
          ),
          TextSpan(
            text: ' / ${formatHours(task.estimate)}',
            style: TextStyle(color: context.colors.dim),
          ),
        ],
      ),
      textAlign: TextAlign.right,
      style: TextStyle(
        fontSize: 11,
        color: context.colors.muted,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
    );
  }
}
