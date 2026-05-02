import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nx_projects/core/formatting/date_label.dart';
import 'package:nx_projects/core/theme/app_theme.dart';
import 'package:nx_projects/data/providers.dart';
import 'package:nx_projects/domain/project/project.dart';
import 'package:nx_projects/domain/task/ideation_status.dart';
import 'package:nx_projects/domain/task/task.dart';
import 'package:nx_projects/domain/task/task_bucket.dart';
import 'package:nx_projects/domain/task/task_kind.dart';
import 'package:nx_projects/domain/task/task_severity.dart';
import 'package:nx_projects/domain/sprint/sprint.dart';
import 'package:nx_projects/domain/task/task_status.dart';
import 'package:nx_projects/features/task_edit/reference_dialog_shell.dart';

Future<void> showTaskEditSheet(
  BuildContext context,
  WidgetRef ref, {
  Task? task,
  int? defaultProject,
  int? defaultSub,
  TaskBucket? defaultBucket,
  required void Function() onSave,
  bool useReferenceDialog = false,
}) {
  if (useReferenceDialog) {
    return showDialog<void>(
      context: context,
      barrierColor: const Color(0x99080A0E),
      barrierDismissible: true,
      builder: (ctx) {
        return TaskEditForm(
          useReferenceDialog: true,
          sidePanel: false,
          onSidePanelClose: null,
          task: task,
          defaultProject: defaultProject,
          defaultSub: defaultSub,
          defaultBucket: defaultBucket,
          onSave: onSave,
        );
      },
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.panel,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return TaskEditForm(
        useReferenceDialog: false,
        sidePanel: false,
        onSidePanelClose: null,
        task: task,
        defaultProject: defaultProject,
        defaultSub: defaultSub,
        defaultBucket: defaultBucket,
        onSave: onSave,
      );
    },
  );
}

/// Task create/edit form: reference dialog, bottom sheet, or [sidePanel] for desktop
/// [ReferenceSideDrawer].
class TaskEditForm extends ConsumerStatefulWidget {
  const TaskEditForm({
    super.key,
    required this.useReferenceDialog,
    this.sidePanel = false,
    this.onSidePanelClose,
    this.task,
    this.defaultProject,
    this.defaultSub,
    this.defaultBucket,
    required this.onSave,
  });

  final bool useReferenceDialog;

  /// When true, this widget fills a parent panel; use [onSidePanelClose] instead
  /// of [Navigator.pop]. Implies not [useReferenceDialog].
  final bool sidePanel;
  final VoidCallback? onSidePanelClose;

  final Task? task;
  final int? defaultProject;
  final int? defaultSub;
  final TaskBucket? defaultBucket;
  final VoidCallback onSave;

  @override
  ConsumerState<TaskEditForm> createState() => _TaskEditFormState();
}

class _TaskEditFormState extends ConsumerState<TaskEditForm> {
  late String _type; // task | feature | bug
  late TextEditingController _title;
  late TextEditingController _est;
  late TextEditingController _notes;
  int? _projectId;
  int? _subProjectId;
  late TaskBucket _bucket;
  TaskSeverity _sev = TaskSeverity.med;
  int? _sprintId;
  String? _plannedFor;
  IdeationStatus _ideation = IdeationStatus.idea;

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    if (t == null) {
      _type = 'task';
      _title = TextEditingController();
      _est = TextEditingController();
      _notes = TextEditingController();
      _projectId = widget.defaultProject;
      _subProjectId = widget.defaultSub;
      _bucket = widget.defaultBucket ?? TaskBucket.unsorted;
      _sprintId = null;
      _plannedFor = null;
      _ideation = IdeationStatus.idea;
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
      _projectId = t.projectId;
      _subProjectId = t.subProjectId;
      _bucket = t.bucket;
      _sprintId = t.sprintId;
      _plannedFor = t.plannedFor;
      if (t.severity != null) _sev = t.severity!;
      if (t.kind == TaskKind.feat) {
        _ideation = t.ideationStatus ?? IdeationStatus.idea;
      } else {
        _ideation = IdeationStatus.idea;
      }
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _est.dispose();
    _notes.dispose();
    super.dispose();
  }

  String _typeHint() {
    return switch (_type) {
      'bug' => 'A defect or regression; includes severity.',
      'feature' => 'A user-facing deliverable, usually with estimate.',
      _ => 'Plain sub-task under a Feature, or a standalone item.',
    };
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
    final projectId = _projectId;
    var subId = _subProjectId;
    final plannedFor = _sprintId == null ? null : _plannedFor;
    final projects = ref.read(projectsListProvider);
    if (subId != null &&
        !projects.any((p) => p.id == subId && p.parentId == projectId)) {
      subId = null;
    }
    Project? proj;
    if (projectId != null) {
      for (final p in projects) {
        if (p.id == projectId) proj = p;
      }
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
    final driftFrom = [...?widget.task?.driftFrom];
    final oldPlannedFor = widget.task?.plannedFor;
    if (oldPlannedFor != null &&
        oldPlannedFor.isNotEmpty &&
        plannedFor != null &&
        oldPlannedFor != plannedFor &&
        !driftFrom.contains(oldPlannedFor)) {
      driftFrom.add(oldPlannedFor);
    }

    final kind = _mapKind();
    var task = Task(
      id: widget.task?.id ?? 0,
      title: title,
      kind: kind,
      projectId: projectId,
      subProjectId: subId,
      crumb: crumb,
      estimate: est,
      actualHours: widget.task?.actualHours ?? 0,
      bucket: _bucket,
      status: widget.task?.status ?? TaskStatus.todo,
      sprintId: _sprintId,
      plannedFor: plannedFor,
      driftFrom: driftFrom,
      notes: _notes.text,
    );
    if (kind == TaskKind.bug) {
      task = task.copyWith(severity: _sev, clearIdeationStatus: true);
    } else if (kind == TaskKind.feat) {
      task = task.copyWith(clearSeverity: true, ideationStatus: _ideation);
    } else {
      task = task.copyWith(clearSeverity: true, clearIdeationStatus: true);
    }
    await ref.read(taskRepositoryProvider).upsert(task);
    ref.invalidate(tasksListAsyncProvider);
    ref.invalidate(allProjectsAsyncProvider);
    ref.invalidate(sprintsListAsyncProvider);
    widget.onSave();
    if (widget.onSidePanelClose != null) {
      widget.onSidePanelClose!();
    } else if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _dismiss() {
    if (widget.onSidePanelClose != null) {
      widget.onSidePanelClose!();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.sidePanel) {
      return _buildSidePanel();
    }
    if (widget.useReferenceDialog) {
      return ReferenceDialog(
        title: widget.task == null ? 'New task' : 'Edit task',
        onClose: _dismiss,
        primaryLabel: widget.task == null ? 'Create task' : 'Save',
        cancelLabel: 'Cancel',
        onPrimary: _submit,
        child: _buildTaskFormBody(),
      );
    }
    return _buildSheet();
  }

  /// Desktop right drawer: scrollable form + foot actions.
  Widget _buildSidePanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: _buildTaskFormBody(),
          ),
        ),
        const Divider(height: 1, color: AppColors.border),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: RefModalActions(
            onCancel: _dismiss,
            onPrimary: _submit,
            cancelLabel: 'Cancel',
            primaryLabel: widget.task == null ? 'Create task' : 'Save',
          ),
        ),
      ],
    );
  }

  Widget _buildTaskFormBody() {
    final roots = ref
        .watch(projectsListProvider)
        .where((p) => p.parentId == null)
        .toList();
    final sprints = ref.watch(sprintsListProvider);
    final selectedSprint = _sprintById(sprints, _sprintId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const RefFieldLabel('Type'),
        const SizedBox(height: 6),
        _refTypeSeg(),
        const SizedBox(height: 4),
        Text(
          _typeHint(),
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.dim,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 14),
        const RefFieldLabel('Title'),
        const SizedBox(height: 6),
        TextField(
          controller: _title,
          style: const TextStyle(color: AppColors.text, fontSize: 13),
          decoration: refFieldDecoration(null, hint: 'What needs to get done?'),
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _refProjectField(roots)),
            const SizedBox(width: 12),
            Expanded(child: _refBucketField()),
          ],
        ),
        if (_subProjectsForSelected(roots).isNotEmpty) ...[
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _refSubProjectField()),
              const SizedBox(width: 12),
              const Spacer(),
            ],
          ),
        ],
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _refEstimateField()),
            const SizedBox(width: 12),
            Expanded(child: _refSprintField(sprints)),
          ],
        ),
        if (selectedSprint != null) ...[
          const SizedBox(height: 14),
          _refSprintDayField(selectedSprint),
        ],
        if (_type == 'bug') ...[
          const SizedBox(height: 14),
          const RefFieldLabel('Severity'),
          const SizedBox(height: 6),
          _refSeveritySeg(),
        ],
        if (_type == 'feature') ...[
          const SizedBox(height: 14),
          _refIdeationField(),
        ],
        const SizedBox(height: 14),
        const RefFieldLabel('Notes', suffixOpt: true),
        const SizedBox(height: 6),
        TextField(
          controller: _notes,
          minLines: 3,
          maxLines: 5,
          style: const TextStyle(color: AppColors.text, fontSize: 13),
          decoration: refFieldDecoration(
            null,
            hint: 'Acceptance criteria, links, context…',
            isDense: false,
          ),
        ),
      ],
    );
  }

  Widget _refTypeSeg() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.panel2,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _refSegBtn(
            value: 'task',
            label: 'Task',
            glyph: '▢',
            glyphColor: AppColors.dim,
            selected: _type == 'task',
            onTap: () => setState(() => _type = 'task'),
          ),
          _refSegBtn(
            value: 'feature',
            label: 'Feature',
            glyph: '◉',
            glyphColor: AppColors.feat,
            selected: _type == 'feature',
            onTap: () => setState(() => _type = 'feature'),
          ),
          _refSegBtn(
            value: 'bug',
            label: 'Bug',
            glyph: '●',
            glyphColor: AppColors.bug,
            selected: _type == 'bug',
            onTap: () => setState(() => _type = 'bug'),
          ),
        ],
      ),
    );
  }

  Widget _refSegBtn({
    required String value,
    required String label,
    required String glyph,
    required Color glyphColor,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? AppColors.panel3 : Colors.transparent,
      borderRadius: BorderRadius.circular(5),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(5),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                glyph,
                style: TextStyle(fontSize: 10, color: glyphColor, height: 1),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: selected ? AppColors.text : AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _refSeveritySeg() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.panel2,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final e in <(String, TaskSeverity)>[
            ('Low', TaskSeverity.low),
            ('Medium', TaskSeverity.med),
            ('Critical', TaskSeverity.crit),
          ])
            _refSevBtn(
              e.$2,
              e.$1,
              _sev == e.$2,
              () => setState(() => _sev = e.$2),
            ),
        ],
      ),
    );
  }

  Widget _refSevBtn(
    TaskSeverity sev,
    String label,
    bool selected,
    VoidCallback onTap,
  ) {
    return Material(
      color: selected ? AppColors.panel3 : Colors.transparent,
      borderRadius: BorderRadius.circular(5),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(5),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: selected ? AppColors.text : AppColors.muted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _refProjectField(List<Project> roots) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const RefFieldLabel('Project'),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: _projectId?.toString(),
          isExpanded: true,
          isDense: true,
          decoration: refFieldDecoration(null),
          dropdownColor: AppColors.panel2,
          style: const TextStyle(color: AppColors.text, fontSize: 13),
          items: [
            const DropdownMenuItem<String>(
              value: null,
              child: Text('— No project —', overflow: TextOverflow.ellipsis),
            ),
            for (final p in roots)
              DropdownMenuItem<String>(
                value: '${p.id}',
                child: Text(p.name, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (v) => setState(() {
            _projectId = v == null ? null : int.tryParse(v);
            _subProjectId = null;
          }),
        ),
      ],
    );
  }

  List<Project> _subProjectsForSelected(List<Project> roots) {
    final selected = _projectId;
    if (selected == null) return const [];
    if (!roots.any((p) => p.id == selected)) return const [];
    return ref
        .watch(projectsListProvider)
        .where((p) => p.parentId == selected)
        .toList();
  }

  Widget _refSubProjectField() {
    final subs = _subProjectsForSelected(
      ref.watch(projectsListProvider).where((p) => p.parentId == null).toList(),
    );
    final validSub = subs.any((p) => p.id == _subProjectId)
        ? _subProjectId?.toString()
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const RefFieldLabel('Subproject'),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          key: ValueKey('subproject-$_projectId-$validSub'),
          initialValue: validSub,
          isExpanded: true,
          isDense: true,
          decoration: refFieldDecoration(null),
          dropdownColor: AppColors.panel2,
          style: const TextStyle(color: AppColors.text, fontSize: 13),
          items: [
            const DropdownMenuItem<String>(
              value: null,
              child: Text('— No subproject —', overflow: TextOverflow.ellipsis),
            ),
            for (final s in subs)
              DropdownMenuItem<String>(
                value: '${s.id}',
                child: Text(s.name, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (v) => setState(() {
            _subProjectId = v == null ? null : int.tryParse(v);
          }),
        ),
      ],
    );
  }

  Widget _refBucketField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const RefFieldLabel('Bucket'),
        const SizedBox(height: 6),
        DropdownButtonFormField<TaskBucket>(
          initialValue: _bucket,
          isExpanded: true,
          isDense: true,
          decoration: refFieldDecoration(null),
          dropdownColor: AppColors.panel2,
          style: const TextStyle(color: AppColors.text, fontSize: 13),
          items: TaskBucket.values
              .map(
                (b) => DropdownMenuItem(
                  value: b,
                  child: Text(switch (b) {
                    TaskBucket.now => 'Now (this sprint)',
                    TaskBucket.next => 'Next (1–2 sprints out)',
                    TaskBucket.later => 'Later',
                    TaskBucket.someday => 'Someday',
                    TaskBucket.unsorted => 'Unsorted',
                  }, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: (v) {
            if (v != null) setState(() => _bucket = v);
          },
        ),
      ],
    );
  }

  Widget _refEstimateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const RefFieldLabel('Estimate (hours)'),
        const SizedBox(height: 6),
        TextField(
          controller: _est,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: AppColors.text, fontSize: 13),
          decoration: refFieldDecoration(null, hint: 'e.g. 4'),
        ),
      ],
    );
  }

  Widget _refSprintField(List<Sprint> sprints) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const RefFieldLabel('Sprint'),
        const SizedBox(height: 6),
        DropdownButtonFormField<int?>(
          initialValue: _sprintId,
          isExpanded: true,
          isDense: true,
          decoration: refFieldDecoration(null),
          dropdownColor: AppColors.panel2,
          style: const TextStyle(color: AppColors.text, fontSize: 13),
          items: [
            const DropdownMenuItem<int?>(
              value: null,
              child: Text(
                '— Backlog (no sprint) —',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            for (final sp in sprints)
              DropdownMenuItem<int?>(
                value: sp.id,
                child: Text(
                  '${sp.name} (${sp.dates})',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (v) => setState(() {
            _sprintId = v;
            final sp = _sprintById(sprints, v);
            if (sp == null || !_sprintContainsDay(sp, _plannedFor)) {
              _plannedFor = null;
            }
          }),
        ),
      ],
    );
  }

  Sprint? _sprintById(List<Sprint> sprints, int? id) {
    if (id == null) return null;
    for (final sp in sprints) {
      if (sp.id == id) return sp;
    }
    return null;
  }

  bool _sprintContainsDay(Sprint sprint, String? ymd) {
    if (ymd == null || ymd.isEmpty) return true;
    final start = parseLocalDate(sprint.start);
    for (var i = 0; i < sprint.length; i++) {
      if (formatYmd(start.add(Duration(days: i))) == ymd) return true;
    }
    return false;
  }

  Widget _refSprintDayField(Sprint sprint) {
    final start = parseLocalDate(sprint.start);
    final validValue = _sprintContainsDay(sprint, _plannedFor)
        ? _plannedFor
        : null;
    if (validValue == null && _plannedFor != null) {
      _plannedFor = null;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const RefFieldLabel('Sprint day'),
        const SizedBox(height: 6),
        DropdownButtonFormField<String?>(
          key: ValueKey('sprint-day-${sprint.id}-$validValue'),
          initialValue: validValue,
          isExpanded: true,
          isDense: true,
          decoration: refFieldDecoration(null),
          dropdownColor: AppColors.panel2,
          style: const TextStyle(color: AppColors.text, fontSize: 13),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text(
                '— Unscheduled in sprint —',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            for (var i = 0; i < sprint.length; i++)
              DropdownMenuItem<String?>(
                value: formatYmd(start.add(Duration(days: i))),
                child: Text(
                  '${DateFormat('EEE, MMM d').format(start.add(Duration(days: i)))} · ${formatYmd(start.add(Duration(days: i)))}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (v) => setState(() => _plannedFor = v),
        ),
      ],
    );
  }

  Widget _refIdeationField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const RefFieldLabel('Ideation status'),
        const SizedBox(height: 6),
        DropdownButtonFormField<IdeationStatus>(
          initialValue: _ideation,
          isExpanded: true,
          isDense: true,
          decoration: refFieldDecoration(null),
          dropdownColor: AppColors.panel2,
          style: const TextStyle(color: AppColors.text, fontSize: 13),
          items: IdeationStatus.values
              .map(
                (e) => DropdownMenuItem(
                  value: e,
                  child: Text(e.displayLabel, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: (v) {
            if (v != null) setState(() => _ideation = v);
          },
        ),
      ],
    );
  }

  Widget _buildSheet() {
    return Padding(
      padding: EdgeInsets.only(
        left: 18,
        right: 18,
        top: 14,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.border2,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              widget.task == null ? 'New task' : 'Edit task',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 12),
            _buildTaskFormBody(),
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 8),
            RefModalActions(
              onCancel: _dismiss,
              onPrimary: _submit,
              cancelLabel: 'Cancel',
              primaryLabel: widget.task == null ? 'Create task' : 'Save',
            ),
          ],
        ),
      ),
    );
  }
}
