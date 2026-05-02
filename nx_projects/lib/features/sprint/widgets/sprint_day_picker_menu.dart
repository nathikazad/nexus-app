import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nx_projects/core/formatting/date_label.dart';
import 'package:nx_projects/core/theme/app_theme.dart';
import 'package:nx_projects/data/providers.dart';
import 'package:nx_projects/domain/sprint/sprint.dart';
import 'package:nx_projects/domain/task/task.dart';
import 'package:nx_projects/features/sprint/assign_task_to_sprint_day.dart';

class SprintDayPickerButton extends ConsumerWidget {
  SprintDayPickerButton({
    super.key,
    required this.task,
    this.sprint,
    this.label,
    this.child,
    this.onChanged,
  });

  static String _unscheduled = '__unscheduled__';

  final Task task;
  final Sprint? sprint;
  final String? label;
  final Widget? child;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sp = sprint ?? _sprintForTask(ref.watch(sprintsListProvider), task);
    if (sp == null) return SizedBox.shrink();

    return PopupMenuButton<String>(
      tooltip: 'Assign sprint day',
      color: context.colors.panel2,
      onSelected: (value) async {
        await assignTaskToSprintDay(
          ref: ref,
          task: task,
          sprint: sp,
          ymd: value == _unscheduled ? null : value,
        );
        onChanged?.call();
      },
      itemBuilder: (context) {
        final days = _daysFor(sp);
        return [
          PopupMenuItem<String>(
            value: _unscheduled,
            child: _MenuRow(
              title: 'Unscheduled in sprint',
              subtitle: sp.name,
              selected: task.plannedFor == null || task.plannedFor!.isEmpty,
            ),
          ),
          PopupMenuDivider(),
          for (final d in days)
            PopupMenuItem<String>(
              value: d.ymd,
              child: _MenuRow(
                title: d.title,
                subtitle: d.ymd,
                selected: task.plannedFor == d.ymd,
              ),
            ),
        ];
      },
      child: child ?? _DefaultPickerChip(label: label ?? _labelFor(task, sp)),
    );
  }

  static Sprint? _sprintForTask(List<Sprint> sprints, Task task) {
    final id = task.sprintId;
    if (id == null) return null;
    for (final s in sprints) {
      if (s.id == id) return s;
    }
    return null;
  }

  static List<_SprintDayOption> _daysFor(Sprint sprint) {
    final start = parseLocalDate(sprint.start);
    return [
      for (var i = 0; i < sprint.length; i++)
        _SprintDayOption(
          ymd: formatYmd(start.add(Duration(days: i))),
          title: DateFormat('EEE, MMM d').format(start.add(Duration(days: i))),
        ),
    ];
  }

  static String _labelFor(Task task, Sprint sprint) {
    final planned = task.plannedFor;
    if (planned == null || planned.isEmpty) return 'Assign day';
    final date = parseLocalDate(planned);
    return DateFormat('EEE, MMM d').format(date);
  }
}

class _SprintDayOption {
  _SprintDayOption({required this.ymd, required this.title});

  final String ymd;
  final String title;
}

class _DefaultPickerChip extends StatelessWidget {
  _DefaultPickerChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: context.colors.panel2,
        border: Border.all(color: context.colors.border),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: context.colors.text),
          ),
          SizedBox(width: 6),
          Icon(Icons.expand_more, size: 14, color: context.colors.dim),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  _MenuRow({
    required this.title,
    required this.subtitle,
    required this.selected,
  });

  final String title;
  final String subtitle;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 20,
          child: selected
              ? Icon(Icons.check, size: 16, color: context.colors.accent)
              : SizedBox.shrink(),
        ),
        SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 13, color: context.colors.text),
            ),
            Text(
              subtitle,
              style: TextStyle(fontSize: 11, color: context.colors.dim),
            ),
          ],
        ),
      ],
    );
  }
}
