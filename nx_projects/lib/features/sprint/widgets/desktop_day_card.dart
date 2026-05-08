import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nx_projects/core/formatting/date_label.dart';
import 'package:nx_projects/core/theme/app_theme.dart';
import 'package:nx_projects/core/widgets/capacity_bar.dart';
import 'package:nx_projects/data/providers.dart';
import 'package:nx_projects/domain/project/project.dart';
import 'package:nx_projects/domain/sprint/sprint.dart';
import 'package:nx_projects/domain/sprint/sprint_state.dart';
import 'package:nx_projects/domain/task/task.dart';
import 'package:nx_projects/features/desktop/desktop_task_locator.dart';
import 'package:nx_projects/features/sprint/sprint_view_model.dart';
import 'package:nx_projects/features/sprint/widgets/day_item_row.dart';

/// Bordered day card for desktop sprint plan (`reference/desktop` `.day`).
class DesktopDayCard extends ConsumerWidget {
  DesktopDayCard({
    super.key,
    required this.slice,
    required this.sprint,
    required this.taskRowKeyFor,
    required this.onOpenTaskMenu,
    required this.onOpenTask,
  });

  final SprintDaySlice slice;
  final Sprint sprint;
  final GlobalKey Function(int taskId, String occurrenceId) taskRowKeyFor;
  final void Function(Task t) onOpenTaskMenu;
  final void Function(Task t) onOpenTask;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = parseLocalDate(slice.ymd);
    final locator = ref.watch(desktopTaskLocatorProvider);
    final projects = ref.watch(projectsListProvider);
    final dayActual = slice.dayActual;
    final gaugeMaxH = 12.0;
    final actualGaugeColor = _gaugeColor(context, dayActual);
    final isToday = slice.isToday;
    final showStats = slice.isPast && slice.taskGroups.isNotEmpty;
    final showDayNote = slice.isPast || sprint.state == SprintState.done;
    return Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: Opacity(
        opacity: slice.isPast ? 0.65 : 1.0,
        child: AnimatedContainer(
          duration: Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: context.colors.panel,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isToday ? context.colors.border2 : context.colors.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(12, 10, 12, 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 30,
                      child: Text(
                        DateFormat('EEE').format(d).toUpperCase(),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.visible,
                        style: TextStyle(
                          fontSize: 10,
                          color: context.colors.dim,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: DateFormat('MMM').format(d),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isToday
                                    ? context.colors.accent
                                    : context.colors.text,
                              ),
                            ),
                            TextSpan(
                              text: ' ${DateFormat('d').format(d)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: context.colors.muted,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            if (isToday)
                              TextSpan(
                                text: '  · today',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.colors.accent,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '${_fmtH(dayActual)}h',
                                style: TextStyle(
                                  color: actualGaugeColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          style: TextStyle(
                            fontSize: 10,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Transform.translate(
                offset: Offset(2, 0),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(10, 0, 10, 8),
                  child: DayCapBar(
                    ratio: dayActual / gaugeMaxH,
                    fillColor: actualGaugeColor,
                    height: 3,
                  ),
                ),
              ),
              if (showStats)
                Padding(
                  padding: EdgeInsets.fromLTRB(12, 0, 12, 6),
                  child: _DayStatsLine(slice: slice, dayActual: dayActual),
                ),
              if (slice.taskGroups.isNotEmpty)
                Padding(
                  padding: EdgeInsets.fromLTRB(6, 0, 6, 8),
                  child: Column(
                    children: [
                      for (final group in slice.taskGroups)
                        Padding(
                          padding: EdgeInsets.only(bottom: 4),
                          child: SizedBox(
                            key: taskRowKeyFor(group.task.id, slice.ymd),
                            child: DayItemRow(
                              task: group.task,
                              actualHours: group.actualHours,
                              priorActualHours: group.priorActualHours,
                              actionCount: group.actionCount,
                              workLinks: group.workLinks,
                              barColor: _projectColorForTask(
                                group.task,
                                projects,
                              ),
                              isLocated: locator.isHighlighted(group.task.id),
                              onTap: () => onOpenTask(group.task),
                              onMenu: () => onOpenTaskMenu(group.task),
                              enableDrag: false,
                            ),
                          ),
                        ),
                    ],
                  ),
                )
              else
                Padding(
                  padding: EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: Text(
                    'No work logged.',
                    style: TextStyle(
                      color: context.colors.dim,
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              if (showDayNote)
                _SprintDayNoteField(
                  key: ValueKey('${sprint.id}_${slice.ymd}'),
                  sprint: sprint,
                  ymd: slice.ymd,
                ),
              SizedBox(height: 2),
            ],
          ),
        ),
      ),
    );
  }

  String _fmtH(double h) {
    if (h == h.roundToDouble()) return h.toInt().toString();
    return h.toStringAsFixed(1);
  }

  Color _gaugeColor(BuildContext context, double hours) {
    if (hours < 4) return context.colors.crit;
    if (hours < 8) return context.colors.warn;
    return context.colors.ok;
  }

  Color? _projectColorForTask(Task task, List<Project> projects) {
    final projectId = task.projectId;
    if (projectId != null) {
      for (final project in projects) {
        if (project.id == projectId) return Color(project.color);
      }
    }

    final subProjectId = task.subProjectId;
    if (subProjectId == null) return null;
    Project? subProject;
    for (final project in projects) {
      if (project.id == subProjectId) {
        subProject = project;
        break;
      }
    }
    final parentId = subProject?.parentId;
    if (parentId != null) {
      for (final project in projects) {
        if (project.id == parentId) return Color(project.color);
      }
    }
    return subProject == null ? null : Color(subProject.color);
  }
}

class _DayStatsLine extends StatelessWidget {
  _DayStatsLine({required this.slice, required this.dayActual});

  final SprintDaySlice slice;
  final double dayActual;

  @override
  Widget build(BuildContext context) {
    final allDone =
        slice.taskGroups.isNotEmpty &&
        slice.doneCount == slice.taskGroups.length;
    return Wrap(
      spacing: 14,
      runSpacing: 4,
      children: [
        _DayStatText(
          icon: '✓',
          value: '${slice.doneCount}/${slice.taskGroups.length}',
          label: 'done',
          color: allDone ? context.colors.ok : context.colors.warn,
        ),
        if (slice.isPast && dayActual == 0)
          Text(
            '· no logged work',
            style: TextStyle(
              fontSize: 11,
              color: context.colors.dim,
              fontStyle: FontStyle.italic,
            ),
          ),
      ],
    );
  }
}

class _DayStatText extends StatelessWidget {
  _DayStatText({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final String icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$icon ',
            style: TextStyle(color: color),
          ),
          TextSpan(
            text: value,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
          TextSpan(
            text: ' $label',
            style: TextStyle(color: color),
          ),
        ],
      ),
      style: TextStyle(
        fontSize: 11,
        color: context.colors.muted,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
    );
  }
}

class _DashedLine extends StatelessWidget {
  _DashedLine();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(double.infinity, 1),
      painter: _DashedLinePainter(context.colors.border),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  _DashedLinePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    final dash = 4.0;
    final gap = 3.0;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, 0),
        Offset((x + dash).clamp(0, size.width), 0),
        paint,
      );
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SprintDayNoteField extends ConsumerStatefulWidget {
  _SprintDayNoteField({super.key, required this.sprint, required this.ymd});

  final Sprint sprint;
  final String ymd;

  @override
  ConsumerState<_SprintDayNoteField> createState() =>
      _SprintDayNoteFieldState();
}

class _SprintDayNoteFieldState extends ConsumerState<_SprintDayNoteField> {
  late TextEditingController _c;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: widget.sprint.dayNotes[widget.ymd] ?? '');
  }

  @override
  void didUpdateWidget(covariant _SprintDayNoteField old) {
    super.didUpdateWidget(old);
    if (old.sprint.id != widget.sprint.id || old.ymd != widget.ymd) {
      _c.text = widget.sprint.dayNotes[widget.ymd] ?? '';
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 2, 12, 8),
      child: Column(
        children: [
          _DashedLine(),
          SizedBox(height: 6),
          TextField(
            controller: _c,
            onChanged: (v) {
              // TODO(nx_projects): persist day notes when Sprint.day_notes exists in PGDB
            },
            maxLines: 1,
            style: TextStyle(fontSize: 11, color: context.colors.text),
            cursorColor: context.colors.accent,
            decoration: InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.zero,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              hintText: 'Short title for this day…',
              hintStyle: TextStyle(
                color: context.colors.dim,
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
