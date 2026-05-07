import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:nx_projects/core/formatting/hours_format.dart';
import 'package:nx_projects/core/theme/app_theme.dart';
import 'package:nx_projects/core/theme/kind_color_palette.dart';
import 'package:nx_projects/domain/task/task.dart';
import 'package:nx_projects/domain/task/task_kind.dart';
import 'package:nx_projects/features/daily/daily_view_model.dart';

class ActionsZone extends StatelessWidget {
  ActionsZone({super.key, required this.actions, this.onOpenTask});

  final List<DailyWorkAction> actions;
  final void Function(Task task)? onOpenTask;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.panel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.colors.border),
        boxShadow: [
          BoxShadow(
            offset: Offset(0, 2),
            blurRadius: 12,
            color: Color(0x32000000),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'ACTIONS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: context.colors.muted,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: 12),
                  child: Divider(color: context.colors.border, height: 1),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          if (actions.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'No actions logged for this day.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.colors.dim,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else
            for (final action in actions)
              Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: _ActionCard(action: action, onOpenTask: onOpenTask),
              ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  _ActionCard({required this.action, this.onOpenTask});

  final DailyWorkAction action;
  final void Function(Task task)? onOpenTask;

  @override
  Widget build(BuildContext context) {
    final duration = action.durationHours;
    final logged = action.loggedHours;
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.panel2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: context.colors.text,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      _timeLabel(action.startTime, action.endTime),
                      style: TextStyle(
                        fontSize: 11,
                        color: context.colors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              if (duration > 0 || logged > 0)
                Text(
                  duration > 0
                      ? formatHoursMinutes(duration)
                      : formatHoursMinutes(logged),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: context.colors.accent,
                  ),
                ),
            ],
          ),
          if (logged > 0 && duration > 0 && (logged - duration).abs() > 0.01)
            Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                '${formatHoursMinutes(logged)} logged across task entries',
                style: TextStyle(fontSize: 11, color: context.colors.warn),
              ),
            ),
          if (action.entries.isNotEmpty) ...[
            SizedBox(height: 10),
            for (final entry in action.entries)
              Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: _ActionEntryRow(entry: entry, onOpenTask: onOpenTask),
              ),
          ],
        ],
      ),
    );
  }
}

class _ActionEntryRow extends StatelessWidget {
  _ActionEntryRow({required this.entry, this.onOpenTask});

  final DailyActionEntry entry;
  final void Function(Task task)? onOpenTask;

  @override
  Widget build(BuildContext context) {
    final task = entry.task;
    final link = entry.link;
    final details = _entryDetails(link);
    final glyph = task.kind == TaskKind.bug
        ? '●'
        : task.kind == TaskKind.feat
        ? '◉'
        : '▢';
    final notes = link.workDescription.trim();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpenTask == null ? null : () => onOpenTask!(task),
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 16,
                child: Text(
                  glyph,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: kindColor(context, task.kind),
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colors.text,
                      ),
                    ),
                    if (details.isNotEmpty) ...[
                      SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          for (final detail in details)
                            _DetailPill(label: detail),
                        ],
                      ),
                    ],
                    if (notes.isNotEmpty) ...[
                      SizedBox(height: 6),
                      Text(
                        notes,
                        style: TextStyle(
                          fontSize: 11,
                          color: context.colors.muted,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailPill extends StatelessWidget {
  _DetailPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: context.colors.panel3,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: context.colors.border),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: context.colors.muted,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

List<String> _entryDetails(TaskWorkLink link) {
  final out = <String>[];
  final timeFmt = DateFormat('h:mm a');
  final start = link.relationStartTime;
  final end = link.relationEndTime;
  final hours = link.timeSpentHours;
  if (start != null) out.add('start ${timeFmt.format(start)}');
  if (end != null) out.add('end ${timeFmt.format(end)}');
  if (hours != null) out.add(formatHoursMinutes(hours));
  return out;
}

String _timeLabel(DateTime? start, DateTime? end) {
  if (start == null && end == null) return 'No time';
  final timeFmt = DateFormat('h:mm a');
  if (start != null && end != null) {
    return '${timeFmt.format(start)} -> ${timeFmt.format(end)}';
  }
  if (start != null) return 'Started ${timeFmt.format(start)}';
  return 'Ended ${timeFmt.format(end!)}';
}
