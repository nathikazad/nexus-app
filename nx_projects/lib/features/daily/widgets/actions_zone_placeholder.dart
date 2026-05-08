import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nx_projects/data/providers.dart';
import 'package:nx_projects/core/formatting/hours_format.dart';
import 'package:nx_projects/core/theme/app_theme.dart';
import 'package:nx_projects/core/theme/kind_color_palette.dart';
import 'package:nx_projects/domain/task/task.dart';
import 'package:nx_projects/domain/task/task_kind.dart';
import 'package:nx_projects/features/daily/daily_view_model.dart';

class ActionsZone extends ConsumerWidget {
  ActionsZone({
    super.key,
    required this.actions,
    required this.day,
    this.onOpenTask,
  });

  final List<DailyWorkAction> actions;
  final DateTime day;
  final void Function(Task task)? onOpenTask;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          OutlinedButton.icon(
            onPressed: () => _createWorkAction(ref, day),
            icon: Icon(Icons.add, size: 16),
            label: Text('Add Work'),
            style: OutlinedButton.styleFrom(
              foregroundColor: context.colors.accent,
              side: BorderSide(color: context.colors.border),
              padding: EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createWorkAction(WidgetRef ref, DateTime day) async {
    final now = DateTime.now();
    final at = DateTime(day.year, day.month, day.day, now.hour, now.minute);
    await ref
        .read(taskRepositoryProvider)
        .createWorkAction(name: 'work', startTime: at, endTime: at);
    ref.invalidate(dailyWorkActionsAsyncProvider);
  }
}

class _ActionCard extends ConsumerWidget {
  _ActionCard({required this.action, this.onOpenTask});

  final DailyWorkAction action;
  final void Function(Task task)? onOpenTask;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final duration = action.durationHours;
    final logged = action.loggedHours;
    final durationLabel = duration > 0
        ? formatHoursMinutes(duration)
        : logged > 0
        ? formatHoursMinutes(logged)
        : null;
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
                    Align(
                      alignment: Alignment.centerLeft,
                      child: InkWell(
                        onTap: () => _editActionTimes(context, ref, action),
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            [
                              _timeLabel(action.startTime, action.endTime),
                              if (durationLabel != null) durationLabel,
                            ].join(' · '),
                            style: TextStyle(
                              fontSize: 11,
                              color: context.colors.muted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              IconButton(
                tooltip: 'Link task',
                onPressed: () => _linkTaskToAction(context, ref, action),
                icon: Icon(Icons.add, size: 18),
                color: context.colors.accent,
                constraints: BoxConstraints.tightFor(width: 32, height: 32),
                padding: EdgeInsets.zero,
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

  Future<void> _linkTaskToAction(
    BuildContext context,
    WidgetRef ref,
    DailyWorkAction action,
  ) async {
    final task = await showDialog<Task>(
      context: context,
      builder: (context) =>
          _TaskPickerDialog(tasks: ref.read(tasksListProvider)),
    );
    if (!context.mounted || task == null) return;
    await showDialog<void>(
      context: context,
      builder: (context) => _ActionWorkLinkDialog(task: task, action: action),
    );
  }

  Future<void> _editActionTimes(
    BuildContext context,
    WidgetRef ref,
    DailyWorkAction action,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _WorkActionTimeDialog(action: action),
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
    final details = _entryDetailLine(link);
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
                    if (details != null) ...[
                      SizedBox(height: 4),
                      Text(
                        details,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: context.colors.muted,
                        ),
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

class _TaskPickerDialog extends StatefulWidget {
  _TaskPickerDialog({required this.tasks});

  final List<Task> tasks;

  @override
  State<_TaskPickerDialog> createState() => _TaskPickerDialogState();
}

class _TaskPickerDialogState extends State<_TaskPickerDialog> {
  int? _taskId;

  @override
  void initState() {
    super.initState();
    if (widget.tasks.length == 1) _taskId = widget.tasks.single.id;
  }

  @override
  Widget build(BuildContext context) {
    final tasks = [...widget.tasks]..sort((a, b) => a.title.compareTo(b.title));
    return AlertDialog(
      backgroundColor: context.colors.panel,
      title: Text('Link task', style: TextStyle(color: context.colors.text)),
      content: SizedBox(
        width: 420,
        child: DropdownButtonFormField<int>(
          initialValue: _taskId,
          isExpanded: true,
          dropdownColor: context.colors.panel2,
          decoration: InputDecoration(labelText: 'Task'),
          selectedItemBuilder: (context) => [
            for (final task in tasks)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _taskLabel(task),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          items: [
            for (final task in tasks)
              DropdownMenuItem<int>(
                value: task.id,
                child: Text(
                  _taskLabel(task),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (value) => setState(() => _taskId = value),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel'),
        ),
        FilledButton(
          onPressed: _taskId == null
              ? null
              : () {
                  final selected = tasks.firstWhere((t) => t.id == _taskId);
                  Navigator.of(context).pop(selected);
                },
          child: Text('Next'),
        ),
      ],
    );
  }
}

class _ActionWorkLinkDialog extends ConsumerStatefulWidget {
  _ActionWorkLinkDialog({required this.task, required this.action});

  final Task task;
  final DailyWorkAction action;

  @override
  ConsumerState<_ActionWorkLinkDialog> createState() =>
      _ActionWorkLinkDialogState();
}

class _ActionWorkLinkDialogState extends ConsumerState<_ActionWorkLinkDialog> {
  late final TextEditingController _startTime;
  late final TextEditingController _endTime;
  late final TextEditingController _hours;
  late final TextEditingController _description;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _startTime = TextEditingController();
    _endTime = TextEditingController();
    _hours = TextEditingController();
    _description = TextEditingController();
  }

  @override
  void dispose() {
    _startTime.dispose();
    _endTime.dispose();
    _hours.dispose();
    _description.dispose();
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

    setState(() => _saving = true);
    try {
      await ref
          .read(taskRepositoryProvider)
          .linkWorkAction(
            taskId: widget.task.id,
            workActionId: widget.action.id,
            workDescription: _description.text,
            timeSpentHours: hours,
            startTime: start,
            endTime: end,
          );
      ref.invalidate(tasksListAsyncProvider);
      ref.invalidate(dailyWorkActionsAsyncProvider);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.colors.panel,
      title: Text(
        'Link ${widget.task.title}',
        style: TextStyle(color: context.colors.text),
      ),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${widget.action.name} · ${_timeLabel(widget.action.startTime, widget.action.endTime)}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: context.colors.muted, fontSize: 12),
              ),
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
              decoration: InputDecoration(labelText: 'Duration hours'),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _description,
              minLines: 3,
              maxLines: 5,
              decoration: InputDecoration(labelText: 'What was done'),
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
}

class _WorkActionTimeDialog extends ConsumerStatefulWidget {
  _WorkActionTimeDialog({required this.action});

  final DailyWorkAction action;

  @override
  ConsumerState<_WorkActionTimeDialog> createState() =>
      _WorkActionTimeDialogState();
}

class _WorkActionTimeDialogState extends ConsumerState<_WorkActionTimeDialog> {
  late final TextEditingController _startTime;
  late final TextEditingController _endTime;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _startTime = TextEditingController(
      text: _dateTimeInputLabel(widget.action.startTime),
    );
    _endTime = TextEditingController(
      text: _dateTimeInputLabel(widget.action.endTime),
    );
  }

  @override
  void dispose() {
    _startTime.dispose();
    _endTime.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final start = _parseDateTimeInput(_startTime.text);
    final end = _parseDateTimeInput(_endTime.text);
    if (_startTime.text.trim().isNotEmpty && start == null) return;
    if (_endTime.text.trim().isNotEmpty && end == null) return;

    setState(() => _saving = true);
    try {
      await ref
          .read(taskRepositoryProvider)
          .updateWorkActionTimes(
            workActionId: widget.action.id,
            startTime: start,
            endTime: end,
          );
      ref.invalidate(dailyWorkActionsAsyncProvider);
      ref.invalidate(tasksListAsyncProvider);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.colors.panel,
      title: Text(
        'Edit Work time',
        style: TextStyle(color: context.colors.text),
      ),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                widget.action.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: context.colors.muted, fontSize: 12),
              ),
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

String? _entryDetailLine(TaskWorkLink link) {
  final start = link.relationStartTime;
  final end = link.relationEndTime;
  final hours = link.timeSpentHours;
  final parts = <String>[];
  if (start != null || end != null) {
    parts.add(_timeLabel(start, end));
  }
  if (hours != null) parts.add(formatHoursMinutes(hours));
  if (parts.isEmpty) return null;
  return parts.join(' · ');
}

String _taskLabel(Task task) {
  if (task.crumb.isEmpty) return task.title;
  return '${task.crumb} · ${task.title}';
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

String _dateTimeInputLabel(DateTime? value) {
  if (value == null) return '';
  return DateFormat('yyyy-MM-dd HH:mm').format(value);
}

DateTime? _parseDateTimeInput(String value) {
  final text = value.trim();
  if (text.isEmpty) return null;
  for (final format in [
    DateFormat('yyyy-MM-dd HH:mm'),
    DateFormat('yyyy-MM-dd h:mm a'),
    DateFormat('yyyy-MM-dd h:mma'),
  ]) {
    try {
      return format.parseStrict(text);
    } on FormatException {
      // Try next format.
    }
  }
  return null;
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
