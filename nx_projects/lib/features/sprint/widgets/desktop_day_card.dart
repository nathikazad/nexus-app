import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nx_projects/core/formatting/date_label.dart';
import 'package:nx_projects/core/formatting/sprint_variance.dart';
import 'package:nx_projects/core/theme/app_theme.dart';
import 'package:nx_projects/core/widgets/capacity_bar.dart';
import 'package:nx_projects/data/providers.dart';
import 'package:nx_projects/domain/sprint/sprint.dart';
import 'package:nx_projects/domain/sprint/sprint_state.dart';
import 'package:nx_projects/domain/task/task.dart';
import 'package:nx_projects/features/sprint/sprint_view_model.dart';
import 'package:nx_projects/features/sprint/widgets/day_item_row.dart';

/// Bordered day card for desktop sprint plan (`reference/desktop` `.day`).
class DesktopDayCard extends ConsumerWidget {
  const DesktopDayCard({
    super.key,
    required this.slice,
    required this.sprint,
    required this.allTasks,
    required this.dailyCap,
    required this.onOpenTaskMenu,
  });

  final SprintDaySlice slice;
  final Sprint sprint;
  final List<Task> allTasks;
  final double dailyCap;
  final void Function(Task t) onOpenTaskMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = parseLocalDate(slice.ymd);
    final dayH = slice.dayHours;
    final dayActual = slice.dayActual;
    final isOver = dailyCap > 0 && dayH > dailyCap;
    final isToday = slice.isToday;
    final ghosts = allTasks
        .where(
          (t) => t.driftFrom.contains(slice.ymd) && t.plannedFor != null && t.plannedFor != slice.ymd,
        )
        .toList();
    final showStats = slice.isPast &&
        (slice.doneCount + slice.pushedCount + slice.rolledCount > 0);
    final showDayNote = slice.isPast || sprint.state == SprintState.done;
    final actualLineCls = dayH > 0
        ? varianceClass(dayActual, dayH)
        : (dayActual > 0 ? 'over' : '');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DragTarget<Task>(
        onWillAcceptWithDetails: (details) {
          final d = details.data;
          if (d.plannedFor == slice.ymd) return false;
          return d.sprintId == sprint.id;
        },
        onAcceptWithDetails: (details) {
          ref.read(plannerProvider.notifier).moveTaskToDay(details.data.id, slice.ymd);
        },
        builder: (context, candidate, rejected) {
          final drop = candidate.isNotEmpty;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              color: drop ? AppColors.accentSoft : AppColors.panel,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: drop ? AppColors.accent : AppColors.border,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 22,
                        child: Text(
                          shortDowLabel(d).toUpperCase(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.dim,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: DateFormat('EEE').format(d),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isToday ? AppColors.accent : AppColors.text,
                                ),
                              ),
                              TextSpan(
                                text: '  ${DateFormat('d').format(d)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.muted,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              TextSpan(
                                text: '  ${DateFormat('MMM').format(d)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.muted,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
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
                                    color: isOver ? AppColors.warn : AppColors.text,
                                    fontWeight: FontWeight.w600,
                                    fontFeatures: const [FontFeature.tabularFigures()],
                                  ),
                                ),
                                TextSpan(
                                  text: ' / ${dailyCap.toStringAsFixed(0)}h',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.muted,
                                    fontFeatures: [FontFeature.tabularFigures()],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (dayH > 0 && (slice.isPast || dayActual > 0)) ...[
                            const SizedBox(height: 2),
                            Text(
                              '${_fmtH(dayActual)}h actual',
                              style: TextStyle(
                                fontSize: 10,
                                color: varianceColorForClass(actualLineCls),
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Transform.translate(
                  offset: const Offset(2, 0),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                    child: DayCapBar(
                      ratio: dailyCap > 0 ? (dayH / dailyCap) : 0,
                      isOver: isOver,
                      height: 3,
                    ),
                  ),
                ),
                if (showStats)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                    child: Text(
                      'done ${slice.doneCount} · pushed ${slice.pushedCount} · rolled ${slice.rolledCount}',
                      style: const TextStyle(fontSize: 11, color: AppColors.dim),
                    ),
                  ),
                if (slice.tasks.isNotEmpty || ghosts.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
                    child: Column(
                      children: [
                        for (final t in slice.tasks)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: DayItemRow(
                              task: t,
                              onMenu: () => onOpenTaskMenu(t),
                            ),
                          ),
                        for (final t in ghosts)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
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
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                    child: Text(
                      drop
                          ? 'Drop here'
                          : 'Drop tasks here to schedule (drag from cart or another day).',
                      style: const TextStyle(
                        color: AppColors.dim,
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
                const SizedBox(height: 2),
              ],
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

class _SprintDayNoteField extends ConsumerStatefulWidget {
  const _SprintDayNoteField({super.key, required this.sprint, required this.ymd});

  final Sprint sprint;
  final String ymd;

  @override
  ConsumerState<_SprintDayNoteField> createState() => _SprintDayNoteFieldState();
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
      padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
      child: TextField(
        controller: _c,
        onChanged: (v) {
          ref.read(plannerProvider.notifier).setDayNote(widget.sprint.id, widget.ymd, v);
        },
        maxLines: 1,
        style: const TextStyle(fontSize: 11, color: AppColors.muted),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          filled: true,
          fillColor: AppColors.panel2,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: AppColors.accent, width: 0.5),
          ),
          hintText: 'Day note…',
          hintStyle: const TextStyle(color: AppColors.dim, fontSize: 11),
        ),
      ),
    );
  }
}
