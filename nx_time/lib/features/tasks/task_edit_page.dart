import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icon_pack/solar_icon_pack.dart';

import 'package:nx_time/core/theme/app_theme.dart';
import 'package:nx_time/data/providers.dart';
import 'package:nx_time/domain/tasks/task.dart';
import 'package:nx_time/features/tasks/projects_browse_page.dart';
import 'package:nx_time/features/tasks/projects_browse_view_model.dart';
import 'package:nx_time/features/tasks/task_form_view_model.dart';
import 'package:nx_time/features/tasks/task_view_models.dart';

class TaskEditPage extends ConsumerStatefulWidget {
  const TaskEditPage({super.key, required this.taskId});

  final int taskId;

  @override
  ConsumerState<TaskEditPage> createState() => _TaskEditPageState();
}

class _TaskEditPageState extends ConsumerState<TaskEditPage> {
  late final TextEditingController _nameCtl;
  late final TextEditingController _notesCtl;
  TaskDraft? _draft;
  int? _pendingProjectId;
  bool _saving = false;
  bool _hydrated = false;

  @override
  void initState() {
    super.initState();
    _nameCtl = TextEditingController();
    _notesCtl = TextEditingController();
    _nameCtl.addListener(() {
      if (_draft != null) _draft!.name = _nameCtl.text;
    });
    _notesCtl.addListener(() {
      if (_draft != null) _draft!.notes = _notesCtl.text;
    });
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _notesCtl.dispose();
    super.dispose();
  }

  void _hydrate(Task task) {
    if (_hydrated) return;
    _hydrated = true;
    _nameCtl.text = task.name;
    _notesCtl.text = task.description ?? '';
    _draft = TaskDraft.fromTask(task);
    _pendingProjectId = task.projectId;
  }

  Future<void> _pickProject() async {
    final id = await Navigator.of(context).push<int?>(
      MaterialPageRoute(
        builder: (_) => const ProjectsBrowsePage(
          mode: ProjectsBrowseMode.pickProject,
        ),
      ),
    );
    if (id != null && mounted) {
      setState(() => _pendingProjectId = id);
    }
  }

  String _projectLabel(Map<int, String> crumbs, int? pid) {
    if (pid == null) return 'None — standalone task';
    return crumbs[pid] ?? 'Project $pid';
  }

  Future<void> _save() async {
    final draft = _draft;
    if (draft == null || !draft.canSave || _saving) return;
    final initial = await ref.read(taskDetailProvider(widget.taskId).future);
    if (initial == null || !mounted) return;

    setState(() => _saving = true);
    try {
      final repo = ref.read(taskRepositoryProvider);
      if (_pendingProjectId != initial.projectId) {
        await repo.moveTaskToProject(
          taskId: widget.taskId,
          projectId: _pendingProjectId,
        );
      }
      final updated = draft.toTaskUpdate(initial);
      await repo.update(updated, includeAttributes: true);
      ref.invalidate(taskDetailProvider(widget.taskId));
      ref.invalidate(tasksForTodayProvider);
      ref.invalidate(allTasksProvider);
      ref.invalidate(projectBreadcrumbLabelsProvider);
      if (mounted) Navigator.of(context).maybePop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final repo = ref.read(taskRepositoryProvider);
    await repo.delete(widget.taskId);
    ref.invalidate(tasksForTodayProvider);
    ref.invalidate(allTasksProvider);
    if (!mounted) return;
    Navigator.of(context).pop();
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final taskAsync = ref.watch(taskDetailProvider(widget.taskId));
    final crumbsAsync = ref.watch(projectBreadcrumbLabelsProvider);
    final crumbs = crumbsAsync.when(
      data: (d) => d,
      loading: () => const <int, String>{},
      error: (_, __) => const <int, String>{},
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: taskAsync.when(
          data: (task) {
            if (task == null) {
              return const Center(child: Text('Task not found'));
            }
            _hydrate(task);
            final draft = _draft!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 12),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.slate500,
                          ),
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          'Edit task',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                            color: AppColors.slate900,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _saving || !draft.canSave ? null : _save,
                        child: Text(
                          'Save',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: draft.canSave && !_saving
                                ? AppColors.accent
                                : AppColors.slate300,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppColors.slate100),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                    children: [
                      _fieldLabel('TASK NAME'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _nameCtl,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _fieldLabel('PARENT PROJECT'),
                      const SizedBox(height: 8),
                      Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          onTap: _pickProject,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.slate200),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  SolarLinearIcons.folder,
                                  size: 20,
                                  color: AppColors.slate600,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _projectLabel(
                                          crumbs,
                                          _pendingProjectId,
                                        ),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.slate900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Text(
                                  'Change',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.accent,
                                  ),
                                ),
                                Icon(
                                  SolarLinearIcons.altArrowRight,
                                  size: 18,
                                  color: AppColors.slate400,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Divider(color: AppColors.slate100),
                      const SizedBox(height: 20),
                      _fieldLabel('TAGS'),
                      const SizedBox(height: 8),
                      Text(
                        draft.tags.isEmpty
                            ? 'No tags'
                            : draft.tags.join(', '),
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.slate600,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Divider(color: AppColors.slate100),
                      const SizedBox(height: 20),
                      _fieldLabel('NOTES'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _notesCtl,
                        minLines: 3,
                        maxLines: 8,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Divider(color: AppColors.slate100),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: _delete,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFEF4444),
                          side: const BorderSide(color: Color(0xFFFECACA)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(SolarLinearIcons.trashBinMinimalistic, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Delete task',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
        ),
      ),
    );
  }

  static Widget _fieldLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 1,
        color: AppColors.slate500,
      ),
    );
  }
}
