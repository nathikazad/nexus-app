import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:nx_projects/core/formatting/date_label.dart';
import 'package:nx_projects/core/theme/app_theme.dart';
import 'package:nx_projects/core/widgets/capacity_bar.dart';
import 'package:nx_projects/domain/task/task.dart';
import 'package:nx_projects/domain/task/task_status.dart';
import 'package:nx_projects/features/sprint/sprint_view_model.dart';
import 'package:nx_projects/features/sprint/widgets/day_item_row.dart';

/// Bordered day card for desktop sprint plan (`reference/desktop` `.day`).
class DesktopDayCard extends StatelessWidget {
  const DesktopDayCard({
    super.key,
    required this.slice,
    required this.dailyCap,
    required this.onOpenTaskMenu,
  });

  final SprintDaySlice slice;
  final double dailyCap;
  final void Function(Task t) onOpenTaskMenu;

  @override
  Widget build(BuildContext context) {
    final d = parseLocalDate(slice.ymd);
    final dayH = slice.dayHours;
    final nDone = slice.tasks.where((t) => t.status == TaskStatus.done).length;
    final meta = slice.tasks.isEmpty
        ? '0'
        : '${slice.tasks.length} · $nDone/${slice.tasks.length} done';
    final capLine = dailyCap > 0 ? '$meta · ${dayH.toStringAsFixed(0)}/${dailyCap.toStringAsFixed(0)}h' : meta;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.panel,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: Row(
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: DateFormat('EEE').format(d),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: slice.isToday ? AppColors.accent : AppColors.text,
                              ),
                            ),
                            TextSpan(
                              text: '  ${DateFormat('MMM d').format(d)}',
                              style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w400),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    capLine,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.muted,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
              child: DayCapBar(
                ratio: dailyCap > 0 ? (dayH / dailyCap) : 0,
                isOver: dailyCap > 0 && dayH > dailyCap,
              ),
            ),
            if (slice.tasks.isNotEmpty)
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
                  ],
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: Text(
                  'Drop tasks here (drag not wired yet).',
                  style: TextStyle(color: AppColors.dim, fontSize: 11, fontStyle: FontStyle.italic),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
