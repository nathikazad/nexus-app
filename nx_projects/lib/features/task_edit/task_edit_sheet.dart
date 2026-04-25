import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nx_projects/core/theme/app_theme.dart';
import 'package:nx_projects/data/providers.dart';
import 'package:nx_projects/domain/project/project.dart';
import 'package:nx_projects/domain/task/task.dart';
import 'package:nx_projects/domain/task/task_bucket.dart';
import 'package:nx_projects/domain/task/task_kind.dart';
import 'package:nx_projects/domain/task/task_severity.dart';
import 'package:nx_projects/domain/task/task_status.dart';

Future<void> showTaskEditSheet(
  BuildContext context,
  WidgetRef ref, {
  Task? task,
  String? defaultProject,
  String? defaultSub,
  TaskBucket? defaultBucket,
  required void Function() onSave,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.panel,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return _TaskEditBody(
        task: task,
        defaultProject: defaultProject,
        defaultSub: defaultSub,
        defaultBucket: defaultBucket,
        onSave: onSave,
      );
    },
  );
}

class _TaskEditBody extends ConsumerStatefulWidget {
  const _TaskEditBody({
    this.task,
    this.defaultProject,
    this.defaultSub,
    this.defaultBucket,
    required this.onSave,
  });

  final Task? task;
  final String? defaultProject;
  final String? defaultSub;
  final TaskBucket? defaultBucket;
  final VoidCallback onSave;

  @override
  ConsumerState<_TaskEditBody> createState() => _TaskEditBodyState();
}

class _TaskEditBodyState extends ConsumerState<_TaskEditBody> {
  late String _type; // task | feature | bug
  late TextEditingController _title;
  late TextEditingController _est;
  late TextEditingController _notes;
  String? _projectVal;
  late TaskBucket _bucket;
  TaskSeverity _sev = TaskSeverity.med;

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    if (t == null) {
      _type = 'task';
      _title = TextEditingController();
      _est = TextEditingController();
      _notes = TextEditingController();
      _projectVal = _combine(widget.defaultProject, widget.defaultSub);
      _bucket = widget.defaultBucket ?? TaskBucket.next;
    } else {
      _type = t.kind == TaskKind.feat
          ? 'feature'
          : t.kind == TaskKind.bug
              ? 'bug'
              : 'task';
      _title = TextEditingController(text: t.title);
      _est = TextEditingController(
        text: t.estimate == 0 ? '' : t.estimate.toString(),
      );
      _notes = TextEditingController(text: t.notes);
      _projectVal = _combine(t.projectId, t.subProjectId);
      _bucket = t.bucket;
      if (t.severity != null) _sev = t.severity!;
    }
  }

  String? _combine(String? p, String? s) {
    if (p == null || p.isEmpty) return null;
    if (s != null && s.isNotEmpty) return '$p/$s';
    return p;
  }

  @override
  void dispose() {
    _title.dispose();
    _est.dispose();
    _notes.dispose();
    super.dispose();
  }

  TaskKind _mapKind() {
    return switch (_type) {
      'bug' => TaskKind.bug,
      'feature' => TaskKind.feat,
      _ => TaskKind.task,
    };
  }

  Future<void> _submit() async {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    final est = double.tryParse(_est.text.trim()) ?? 0;
    String? projectId;
    String? subId;
    final pv = _projectVal;
    if (pv != null && pv.contains('/')) {
      final p = pv.split('/');
      projectId = p[0];
      subId = p[1];
    } else {
      projectId = pv;
    }
    final projects = ref.read(projectsListProvider);
    Project? proj;
    for (final p in projects) {
      if (p.id == projectId) proj = p;
    }
    Project? sub;
    if (subId != null) {
      for (final p in projects) {
        if (p.id == subId) sub = p;
      }
    }
    var crumb = '—';
    if (proj != null) {
      crumb = sub != null ? '${proj.name} / ${sub.name}' : proj.name;
    }

    final kind = _mapKind();
    final id = widget.task?.id ?? 'n${DateTime.now().millisecondsSinceEpoch}';
    var task = Task(
      id: id,
      title: title,
      kind: kind,
      projectId: projectId,
      subProjectId: subId,
      crumb: crumb,
      estimate: est,
      bucket: _bucket,
      status: widget.task?.status ?? TaskStatus.todo,
      sprintId: widget.task?.sprintId,
      plannedFor: widget.task?.plannedFor,
      notes: _notes.text,
    );
    if (kind == TaskKind.bug) {
      task = task.copyWith(severity: _sev);
    } else {
      task = task.copyWith(clearSeverity: true);
    }
    await ref.read(taskRepositoryProvider).upsert(task);
    widget.onSave();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final roots = ref.watch(projectsListProvider).where((p) => p.parentId == null).toList();
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.task == null ? 'New task' : 'Edit task',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'TYPE',
              style: TextStyle(fontSize: 11, color: AppColors.muted),
            ),
            const SizedBox(height: 6),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'task', label: Text('Task')),
                ButtonSegment(value: 'feature', label: Text('Feature')),
                ButtonSegment(value: 'bug', label: Text('Bug')),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              style: const TextStyle(color: AppColors.text),
              decoration: const InputDecoration(
                labelText: 'Title',
                labelStyle: TextStyle(color: AppColors.muted),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _projectVal,
              decoration: const InputDecoration(
                labelText: 'Project',
                labelStyle: TextStyle(color: AppColors.muted),
                border: OutlineInputBorder(),
              ),
              dropdownColor: AppColors.panel2,
              style: const TextStyle(color: AppColors.text),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('— No project —'),
                ),
                for (final p in roots) ...[
                  DropdownMenuItem<String>(
                    value: p.id,
                    child: Text('${p.name} (top level)'),
                  ),
                  for (final s in ref.watch(projectsListProvider)
                      .where((x) => x.parentId == p.id))
                    DropdownMenuItem<String>(
                      value: '${p.id}/${s.id}',
                      child: Text('${p.name} / ${s.name}'),
                    ),
                ],
              ],
              onChanged: (v) => setState(() => _projectVal = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<TaskBucket>(
              value: _bucket,
              decoration: const InputDecoration(
                labelText: 'Bucket',
                labelStyle: TextStyle(color: AppColors.muted),
                border: OutlineInputBorder(),
              ),
              dropdownColor: AppColors.panel2,
              style: const TextStyle(color: AppColors.text),
              items: TaskBucket.values
                  .where((b) => b != TaskBucket.unsorted)
                  .map(
                    (b) => DropdownMenuItem(
                      value: b,
                      child: Text(switch (b) {
                        TaskBucket.now => 'Now',
                        TaskBucket.next => 'Next',
                        TaskBucket.later => 'Later',
                        TaskBucket.someday => 'Someday',
                        TaskBucket.unsorted => 'Unsorted',
                      }),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _bucket = v);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _est,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: AppColors.text),
              decoration: const InputDecoration(
                labelText: 'Estimate (hours)',
                labelStyle: TextStyle(color: AppColors.muted),
                border: OutlineInputBorder(),
              ),
            ),
            if (_type == 'bug') ...[
              const SizedBox(height: 12),
              const Text('SEVERITY', style: TextStyle(fontSize: 11, color: AppColors.muted)),
              const SizedBox(height: 6),
              SegmentedButton<TaskSeverity>(
                segments: const [
                  ButtonSegment(value: TaskSeverity.low, label: Text('Low')),
                  ButtonSegment(value: TaskSeverity.med, label: Text('Med')),
                  ButtonSegment(value: TaskSeverity.crit, label: Text('Crit')),
                ],
                selected: {_sev},
                onSelectionChanged: (s) => setState(() => _sev = s.first),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              minLines: 2,
              maxLines: 4,
              style: const TextStyle(color: AppColors.text),
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                labelStyle: TextStyle(color: AppColors.muted),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _submit,
                    child: Text(widget.task == null ? 'Create' : 'Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
