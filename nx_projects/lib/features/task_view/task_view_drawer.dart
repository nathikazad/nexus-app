import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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
                _WorkActionsSection(task: task),
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

class _WorkActionsSection extends ConsumerWidget {
  _WorkActionsSection({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _TaskViewBody._sectionTitle(context, 'Work actions'),
            ),
            TextButton.icon(
              onPressed: () => _openWorkLinkDialog(context, task: task),
              icon: Icon(Icons.add, size: 16),
              label: Text('Link Work'),
              style: TextButton.styleFrom(
                foregroundColor: context.colors.accent,
                textStyle: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        if (task.workLinks.isEmpty)
          Text(
            'No Work actions linked.',
            style: TextStyle(
              color: context.colors.dim,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          )
        else
          for (final link in task.workLinks)
            Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: _WorkActionLinkCard(task: task, link: link),
            ),
      ],
    );
  }
}

class _WorkActionLinkCard extends ConsumerWidget {
  _WorkActionLinkCard({required this.task, required this.link});

  final Task task;
  final TaskWorkLink link;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hours = link.timeSpentHours;
    return Container(
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.colors.panel2,
        border: Border.all(color: context.colors.border),
        borderRadius: BorderRadius.circular(8),
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
                      link.workActionName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.colors.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      _workTimeLabel(link.startTime, link.endTime),
                      style: TextStyle(
                        color: context.colors.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.only(left: 8),
                child: SizedBox(
                  height: 28,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hours != null)
                        Padding(
                          padding: EdgeInsets.only(right: 6),
                          child: Text(
                            '${_fmtHours(hours)}h',
                            style: TextStyle(
                              color: context.colors.accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      IconButton(
                        tooltip: 'Edit link',
                        onPressed: () => _openWorkLinkDialog(
                          context,
                          task: task,
                          link: link,
                        ),
                        icon: Icon(Icons.edit_outlined, size: 16),
                        style: IconButton.styleFrom(
                          foregroundColor: context.colors.muted,
                          minimumSize: Size(28, 28),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Delete link',
                        onPressed: () async {
                          await ref
                              .read(taskRepositoryProvider)
                              .deleteWorkLink(
                                taskId: task.id,
                                relationId: link.relationId,
                              );
                          ref.invalidate(tasksListAsyncProvider);
                        },
                        icon: Icon(Icons.delete_outline, size: 16),
                        style: IconButton.styleFrom(
                          foregroundColor: context.colors.crit,
                          minimumSize: Size(28, 28),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (link.workDescription.trim().isNotEmpty) ...[
            SizedBox(height: 8),
            Text(
              link.workDescription,
              style: TextStyle(
                color: context.colors.text,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

Future<void> _openWorkLinkDialog(
  BuildContext context, {
  required Task task,
  TaskWorkLink? link,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _WorkLinkDialog(task: task, link: link),
  );
}

class _WorkLinkDialog extends ConsumerStatefulWidget {
  _WorkLinkDialog({required this.task, this.link});

  final Task task;
  final TaskWorkLink? link;

  @override
  ConsumerState<_WorkLinkDialog> createState() => _WorkLinkDialogState();
}

class _WorkLinkDialogState extends ConsumerState<_WorkLinkDialog> {
  late final TextEditingController _description;
  late final TextEditingController _hours;
  late final TextEditingController _startTime;
  late final TextEditingController _endTime;
  int? _workActionId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final link = widget.link;
    _workActionId = link?.workActionId;
    _description = TextEditingController(text: link?.workDescription ?? '');
    _hours = TextEditingController(
      text: link?.timeSpentHours == null
          ? ''
          : _fmtHours(link!.timeSpentHours!),
    );
    _startTime = TextEditingController(
      text: _dateTimeInputLabel(link?.relationStartTime),
    );
    _endTime = TextEditingController(
      text: _dateTimeInputLabel(link?.relationEndTime),
    );
  }

  @override
  void dispose() {
    _description.dispose();
    _hours.dispose();
    _startTime.dispose();
    _endTime.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final hoursText = _hours.text.trim();
    final hours = hoursText.isEmpty ? null : double.tryParse(hoursText);
    if (hoursText.isNotEmpty && hours == null) return;
    final start = _parseDateTimeInput(_startTime.text);
    final end = _parseDateTimeInput(_endTime.text);
    if (_startTime.text.trim().isNotEmpty && start == null) return;
    if (_endTime.text.trim().isNotEmpty && end == null) return;
    final selected = _workActionId;
    if (widget.link == null && selected == null) return;

    setState(() => _saving = true);
    try {
      final repo = ref.read(taskRepositoryProvider);
      final link = widget.link;
      if (link == null) {
        await repo.linkWorkAction(
          taskId: widget.task.id,
          workActionId: selected!,
          workDescription: _description.text,
          timeSpentHours: hours,
          startTime: start,
          endTime: end,
        );
      } else {
        await repo.updateWorkLink(
          taskId: widget.task.id,
          relationId: link.relationId,
          workActionId: link.workActionId,
          workDescription: _description.text,
          timeSpentHours: hours,
          startTime: start,
          endTime: end,
        );
      }
      ref.invalidate(tasksListAsyncProvider);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.link != null;
    return AlertDialog(
      backgroundColor: context.colors.panel,
      title: Text(
        editing ? 'Edit Work link' : 'Link Work action',
        style: TextStyle(color: context.colors.text),
      ),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (editing)
              _readonlyWorkField(context, widget.link!)
            else
              FutureBuilder<List<WorkActionOption>>(
                future: ref.read(taskRepositoryProvider).listWorkActions(),
                builder: (context, snap) {
                  final options = snap.data ?? const <WorkActionOption>[];
                  return DropdownButtonFormField<int>(
                    initialValue: _workActionId,
                    isExpanded: true,
                    dropdownColor: context.colors.panel2,
                    decoration: InputDecoration(labelText: 'Work action'),
                    selectedItemBuilder: (context) => [
                      for (final option in options)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _workOptionLabel(option),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    items: [
                      for (final option in options)
                        DropdownMenuItem<int>(
                          value: option.id,
                          child: Text(
                            _workOptionLabel(option),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: _saving
                        ? null
                        : (value) {
                            setState(() {
                              _workActionId = value;
                            });
                          },
                  );
                },
              ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _DateTimeInputField(
                    controller: _startTime,
                    labelText: 'Start time',
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _DateTimeInputField(
                    controller: _endTime,
                    labelText: 'End time',
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            TextField(
              controller: _hours,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'Time spent hours'),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _description,
              minLines: 3,
              maxLines: 5,
              decoration: InputDecoration(labelText: 'Work description'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save'),
        ),
      ],
    );
  }

  Widget _readonlyWorkField(BuildContext context, TaskWorkLink link) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        '${link.workActionName} · ${_workTimeLabel(link.startTime, link.endTime)}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: context.colors.muted, fontSize: 12),
      ),
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

class _DateTimeInputField extends StatelessWidget {
  _DateTimeInputField({required this.controller, required this.labelText});

  final TextEditingController controller;
  final String labelText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      readOnly: true,
      onTap: () => _pickDateTimeInput(context, controller),
      decoration: InputDecoration(
        labelText: labelText,
        hintText: 'Choose date and time',
        suffixIcon: IconButton(
          tooltip: 'Clear',
          icon: Icon(Icons.close, size: 16),
          onPressed: controller.clear,
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

String _fmtHours(double h) {
  if (h == h.roundToDouble()) return h.toInt().toString();
  return h
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

String _workTimeLabel(DateTime? start, DateTime? end) {
  if (start == null && end == null) return 'No time';
  final base = start ?? end!;
  final date = DateFormat('MMM d').format(base);
  final startText = start == null ? null : DateFormat('h:mm a').format(start);
  final endText = end == null ? null : DateFormat('h:mm a').format(end);
  if (startText != null && endText != null) {
    return '$date · $startText–$endText';
  }
  return '$date · ${startText ?? endText}';
}

String _workOptionLabel(WorkActionOption option) {
  return '${option.name} · ${_workTimeLabel(option.startTime, option.endTime)}';
}

String _dateTimeInputLabel(DateTime? value) {
  if (value == null) return '';
  return DateFormat('yyyy-MM-dd HH:mm').format(value);
}

DateTime? _parseDateTimeInput(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;
  return DateTime.tryParse(text) ??
      DateTime.tryParse(text.replaceFirst(' ', 'T'));
}

Future<void> _pickDateTimeInput(
  BuildContext context,
  TextEditingController controller,
) async {
  final initial = _parseDateTimeInput(controller.text) ?? DateTime.now();
  final date = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(2000),
    lastDate: DateTime(2100),
  );
  if (!context.mounted || date == null) return;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initial),
  );
  if (time == null) return;
  controller.text = _dateTimeInputLabel(
    DateTime(date.year, date.month, date.day, time.hour, time.minute),
  );
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
