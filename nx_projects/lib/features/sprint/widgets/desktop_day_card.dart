import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nx_projects/core/formatting/date_label.dart';
import 'package:nx_projects/core/formatting/sprint_variance.dart';
import 'package:nx_projects/core/theme/app_theme.dart';
import 'package:nx_projects/core/widgets/capacity_bar.dart';
import 'package:nx_projects/domain/sprint/sprint.dart';
import 'package:nx_projects/domain/sprint/sprint_state.dart';
import 'package:nx_projects/domain/task/task.dart';
import 'package:nx_projects/features/desktop/desktop_task_locator.dart';
import 'package:nx_projects/features/sprint/assign_task_to_sprint_day.dart';
import 'package:nx_projects/features/sprint/sprint_view_model.dart';
import 'package:nx_projects/features/sprint/widgets/day_item_row.dart';

/// Bordered day card for desktop sprint plan (`reference/desktop` `.day`).
class DesktopDayCard extends ConsumerWidget {
  DesktopDayCard({
    super.key,
    required this.slice,
    required this.sprint,
    required this.allTasks,
    required this.dailyCap,
    required this.taskRowKeyFor,
    required this.onOpenTaskMenu,
    required this.onOpenTask,
  });

  final SprintDaySlice slice;
  final Sprint sprint;
  final List<Task> allTasks;
  final double dailyCap;
  final GlobalKey Function(int taskId) taskRowKeyFor;
  final void Function(Task t) onOpenTaskMenu;
  final void Function(Task t) onOpenTask;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = parseLocalDate(slice.ymd);
    final locator = ref.watch(desktopTaskLocatorProvider);
    final dayH = slice.dayHours;
    final dayActual = slice.dayActual;
    final isOver = dailyCap > 0 && dayH > dailyCap;
    final isToday = slice.isToday;
    final ghosts = allTasks
        .where(
          (t) =>
              t.driftFrom.contains(slice.ymd) &&
              t.plannedFor != null &&
              t.plannedFor != slice.ymd,
        )
        .toList();
    final showStats =
        slice.isPast &&
        (slice.tasks.isNotEmpty ||
            slice.pushedCount > 0 ||
            slice.rolledCount > 0);
    final showDayNote = slice.isPast || sprint.state == SprintState.done;
    final actualLineCls = dayH > 0
        ? varianceClass(dayActual, dayH)
        : (dayActual > 0 ? 'over' : '');

    return Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: DragTarget<Task>(
        onWillAcceptWithDetails: (details) {
          final d = details.data;
          if (d.plannedFor == slice.ymd) return false;
          return d.sprintId == sprint.id;
        },
        onAcceptWithDetails: (details) async {
          await assignTaskToSprintDay(
            ref: ref,
            task: details.data,
            sprint: sprint,
            ymd: slice.ymd,
          );
        },
        builder: (context, candidate, rejected) {
          final drop = candidate.isNotEmpty;
          final borderColor = drop
              ? context.colors.accent
              : (isToday ? context.colors.border2 : context.colors.border);
          return Opacity(
            opacity: slice.isPast ? 0.65 : 1.0,
            child: AnimatedContainer(
              duration: Duration(milliseconds: 120),
              decoration: BoxDecoration(
                color: drop ? context.colors.accentSoft : context.colors.panel,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderColor),
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
                                    text: _fmtH(dayH),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isOver
                                          ? context.colors.warn
                                          : context.colors.text,
                                      fontWeight: FontWeight.w600,
                                      fontFeatures: [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                  TextSpan(
                                    text: ' / ${dailyCap.toStringAsFixed(0)}h',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: context.colors.muted,
                                      fontFeatures: [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (dayH > 0 &&
                                (slice.isPast || dayActual > 0)) ...[
                              SizedBox(height: 2),
                              Text(
                                '${_fmtH(dayActual)}h actual',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: varianceColorForClass(
                                    context,
                                    actualLineCls,
                                  ),
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                            ],
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
                        ratio: dailyCap > 0 ? (dayH / dailyCap) : 0,
                        isOver: isOver,
                        height: 3,
                      ),
                    ),
                  ),
                  if (showStats)
                    Padding(
                      padding: EdgeInsets.fromLTRB(12, 0, 12, 6),
                      child: _DayStatsLine(slice: slice, dayActual: dayActual),
                    ),
                  if (slice.tasks.isNotEmpty || ghosts.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.fromLTRB(6, 0, 6, 8),
                      child: Column(
                        children: [
                          for (final t in slice.tasks)
                            Padding(
                              padding: EdgeInsets.only(bottom: 4),
                              child: SizedBox(
                                key: taskRowKeyFor(t.id),
                                child: DayItemRow(
                                  task: t,
                                  isLocated: locator.isHighlighted(t.id),
                                  onTap: () => onOpenTask(t),
                                  onMenu: () => onOpenTaskMenu(t),
                                ),
                              ),
                            ),
                          for (final t in ghosts)
                            Padding(
                              padding: EdgeInsets.only(bottom: 4),
                              child: DayItemRow(
                                task: t,
                                isGhost: true,
                                movedToYmd: t.plannedFor!,
                              ),
                            ),
                        ],
                      ),
                    )
                  else
                    Padding(
                      padding: EdgeInsets.fromLTRB(12, 0, 12, 10),
                      child: Text(
                        drop ? 'Drop here' : 'Nothing scheduled.',
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
          );
        },
      ),
    );
  }

  String _fmtH(double h) {
    if (h == h.roundToDouble()) return h.toInt().toString();
    return h.toStringAsFixed(1);
  }
}

class _DayStatsLine extends StatelessWidget {
  _DayStatsLine({required this.slice, required this.dayActual});

  final SprintDaySlice slice;
  final double dayActual;

  @override
  Widget build(BuildContext context) {
    final allDone =
        slice.tasks.isNotEmpty && slice.doneCount == slice.tasks.length;
    return Wrap(
      spacing: 14,
      runSpacing: 4,
      children: [
        _DayStatText(
          icon: '✓',
          value: '${slice.doneCount}/${slice.tasks.length}',
          label: 'done',
          color: allDone ? context.colors.ok : context.colors.warn,
        ),
        if (slice.pushedCount > 0)
          _DayStatText(
            icon: '↗',
            value: '${slice.pushedCount}',
            label: 'pushed out',
            color: context.colors.warn,
          ),
        if (slice.rolledCount > 0)
          _DayStatText(
            icon: '↙',
            value: '${slice.rolledCount}',
            label: 'rolled in',
            color: context.colors.accent,
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
