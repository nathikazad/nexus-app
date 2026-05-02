import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nx_projects/core/theme/app_theme.dart';
import 'package:nx_projects/core/theme/status_color_palette.dart'
    as status_palette;
import 'package:nx_projects/data/providers.dart';
import 'package:nx_projects/domain/sprint/sprint.dart';
import 'package:nx_projects/domain/task/task.dart';
import 'package:nx_projects/domain/task/task_bucket.dart';
import 'package:nx_projects/domain/task/task_kind.dart';
import 'package:nx_projects/domain/task/task_severity.dart';
import 'package:nx_projects/domain/task/task_status.dart';
import 'package:nx_projects/features/desktop/desktop_task_drawer_state.dart';
import 'package:nx_projects/features/shared/widgets/desktop_task_row.dart';

/// Read-only task detail for the desktop right-side drawer (`reference/desktop/view-task.html`).
class TaskViewDrawerContent extends ConsumerWidget {
  TaskViewDrawerContent({
    super.key,
    required this.taskId,
    required this.onClose,
  });

  final int taskId;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(tasksListProvider);
    Task? t;
    for (final x in tasks) {
      if (x.id == taskId) {
        t = x;
        break;
      }
    }
    if (t == null) {
      return Padding(
        padding: EdgeInsets.all(20),
        child: Text(
          'Task #$taskId not found (it may have been removed).',
          style: TextStyle(color: context.colors.muted, fontSize: 13),
        ),
      );
    }
    final sprints = ref.watch(sprintsListProvider);
    Sprint? sp;
    if (t.sprintId != null) {
      for (final s in sprints) {
        if (s.id == t.sprintId) {
          sp = s;
          break;
        }
      }
    }
    return _TaskViewBody(task: t, sprint: sp, onClose: onClose);
  }
}

class _TaskViewBody extends ConsumerWidget {
  _TaskViewBody({required this.task, this.sprint, required this.onClose});

  final Task task;
  final Sprint? sprint;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String glyph;
    String kindLabel;
    Color gColor;
    switch (task.kind) {
      case TaskKind.bug:
        glyph = '●';
        kindLabel = 'Bug';
        gColor = context.colors.bug;
      case TaskKind.feat:
        glyph = '◉';
        kindLabel = 'Feature';
        gColor = context.colors.feat;
      case TaskKind.task:
        glyph = '▢';
        kindLabel = 'Task';
        gColor = context.colors.dim;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Row(
            children: [
              TextButton(onPressed: onClose, child: Text('Back')),
              Spacer(),
              FilledButton(
                onPressed: () {
                  ref.read(desktopTaskDrawerProvider.notifier).editTask(task);
                },
                child: Text('Edit', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      glyph,
                      style: TextStyle(
                        fontSize: 18,
                        color: gColor,
                        height: 1.1,
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            kindLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.6,
                              color: gColor,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            task.title,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: context.colors.text,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: onClose,
                      icon: Icon(Icons.close, size: 20),
                      style: IconButton.styleFrom(
                        foregroundColor: context.colors.muted,
                      ),
                    ),
                  ],
                ),
                if (task.crumb.isNotEmpty) ...[
                  SizedBox(height: 8),
                  Text(
                    task.crumb,
                    style: TextStyle(fontSize: 12, color: context.colors.muted),
                  ),
                ],
                SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _pill(
                      context,
                      'Bucket: ${_bucketLabel(task.bucket)}',
                      context.colors.panel2,
                    ),
                    _pill(
                      context,
                      sprint == null
                          ? 'Sprint: ${desktopSprintChipLabelForTask(task, ref.watch(sprintsListProvider))} (backlog)'
                          : 'Sprint: ${sprint!.name} (${sprint!.dates})',
                      context.colors.panel2,
                    ),
                  ],
                ),
                SizedBox(height: 16),
                _StatusChanger(task: task),
                SizedBox(height: 20),
                _metaRow(
                  context,
                  'Estimate',
                  task.estimate == 0 ? '—' : '${task.estimate}h',
                ),
                if (task.actualHours > 0)
                  _metaRow(context, 'Actual', '${task.actualHours}h'),
                if (task.plannedFor != null)
                  _metaRow(context, 'Planned', task.plannedFor!),
                if (task.driftFrom.isNotEmpty)
                  _metaRow(context, 'Drift from', task.driftFrom.join(', ')),
                if (task.kind == TaskKind.bug) ...[
                  SizedBox(height: 8),
                  _sectionTitle(context, 'Severity'),
                  SizedBox(height: 4),
                  Text(
                    task.severity == null
                        ? '—'
                        : _severityLabel(task.severity!),
                    style: TextStyle(color: context.colors.text, fontSize: 13),
                  ),
                ],
                if (task.kind == TaskKind.feat) ...[
                  SizedBox(height: 8),
                  _sectionTitle(context, 'Ideation'),
                  SizedBox(height: 4),
                  Text(
                    task.ideationStatus?.displayLabel ?? '—',
                    style: TextStyle(color: context.colors.text, fontSize: 13),
                  ),
                ],
                SizedBox(height: 16),
                _sectionTitle(context, 'Notes'),
                SizedBox(height: 6),
                if (task.notes.isEmpty)
                  Text(
                    '—',
                    style: TextStyle(color: context.colors.dim, fontSize: 13),
                  )
                else
                  Text(
                    task.notes,
                    style: TextStyle(
                      color: context.colors.text,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                SizedBox(height: 24),
                Text(
                  'Sub-tasks, drift map, and history are not available in the app data model yet.',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.colors.dim,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static Widget _pill(BuildContext context, String text, Color bg) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: context.colors.border),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          color: context.colors.muted,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  static Widget _metaRow(BuildContext context, String k, String v) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              k,
              style: TextStyle(
                fontSize: 11,
                color: context.colors.muted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              v,
              style: TextStyle(fontSize: 12, color: context.colors.text),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _sectionTitle(BuildContext context, String t) {
    return Text(
      t,
      style: TextStyle(
        fontSize: 11,
        color: context.colors.muted,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
      ),
    );
  }
}

class _StatusChanger extends ConsumerWidget {
  _StatusChanger({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        SizedBox(
          width: 88,
          child: Text(
            'Status',
            style: TextStyle(fontSize: 12, color: context.colors.muted),
          ),
        ),
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final status in TaskStatus.values)
                _StatusButton(
                  status: status,
                  selected: task.status == status,
                  onTap: () => _setTaskStatus(ref, task, status),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusButton extends StatelessWidget {
  _StatusButton({
    required this.status,
    required this.selected,
    required this.onTap,
  });

  final TaskStatus status;
  final bool selected;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final fg = status_palette.statusForeground(context, status);
    final bg = selected
        ? status_palette.statusBackground(context, status) ??
              context.colors.panel3
        : context.colors.panel2;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: selected ? null : onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: selected ? fg : context.colors.border),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            _statusLabel(status),
            style: TextStyle(
              color: selected ? fg : context.colors.muted,
              fontSize: 11,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _setTaskStatus(WidgetRef ref, Task task, TaskStatus status) async {
  if (task.status == status) return;
  await ref.read(taskRepositoryProvider).upsert(task.copyWith(status: status));
  ref.invalidate(tasksListAsyncProvider);
}

String _statusLabel(TaskStatus s) {
  return switch (s) {
    TaskStatus.todo => 'To do',
    TaskStatus.doing => 'Doing',
    TaskStatus.done => 'Done',
    TaskStatus.blocked => 'Blocked',
  };
}

String _bucketLabel(TaskBucket b) {
  return switch (b) {
    TaskBucket.now => 'Now',
    TaskBucket.next => 'Next',
    TaskBucket.later => 'Later',
    TaskBucket.someday => 'Someday',
    TaskBucket.unsorted => 'Unsorted',
  };
}

String _severityLabel(TaskSeverity s) {
  return switch (s) {
    TaskSeverity.low => 'Low',
    TaskSeverity.med => 'Medium',
    TaskSeverity.crit => 'Critical',
  };
}
