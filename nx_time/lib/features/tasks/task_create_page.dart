import 'package:nx_time/data/domains/domain_workspace.dart';
import 'package:nx_time/features/domains/time_domain_gate.dart';
import 'package:nx_time/features/calendar/calendar_datetime_field.dart';
import 'package:nx_time/features/calendar/calendar_feed_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icon_pack/solar_icon_pack.dart';

import 'package:nx_time/core/theme/app_theme.dart';
import 'package:nx_time/data/providers.dart';
import 'package:nx_time/features/tasks/projects_browse_page.dart';
import 'package:nx_time/features/tasks/projects_browse_view_model.dart';
import 'package:nx_time/features/tasks/task_form_view_model.dart';
import 'package:nx_time/features/tasks/task_view_models.dart';

/// New task (`reference/partials/page-task-create.html`).
class TaskCreatePage extends ConsumerStatefulWidget {
  const TaskCreatePage({super.key, this.parentTaskId, this.initialProjectId});

  final int? parentTaskId;
  final int? initialProjectId;

  @override
  ConsumerState<TaskCreatePage> createState() => _TaskCreatePageState();
}

class _TaskCreatePageState extends ConsumerState<TaskCreatePage> {
  late final TextEditingController _nameCtl;
  late final TextEditingController _notesCtl;
  late TaskDraft _draft;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtl = TextEditingController();
    _notesCtl = TextEditingController();
    _draft = TaskDraft(projectId: widget.initialProjectId);
    _nameCtl.addListener(() {
      setState(() => _draft.name = _nameCtl.text);
    });
    _notesCtl.addListener(() {
      setState(() => _draft.notes = _notesCtl.text);
    });
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _notesCtl.dispose();
    super.dispose();
  }

  Future<void> _pickProject() async {
    final id = await Navigator.of(context).push<int?>(
      MaterialPageRoute(
        builder: (_) =>
            const ProjectsBrowsePage(mode: ProjectsBrowseMode.pickProject),
      ),
    );
    if (id != null && mounted) {
      setState(() => _draft.projectId = id);
    }
  }

  String _projectLabel(Map<int, String> crumbs) {
    final pid = _draft.projectId;
    if (pid == null) return 'None — standalone task';
    return crumbs[pid] ?? 'Project $pid';
  }

  Future<void> _save() async {
    if (!_draft.canSave || _saving) return;
    final schema = await ref.read(taskSchemaProvider.future);
    setState(() => _saving = true);
    try {
      final domain = await chooseCreationDomain(
        context,
        ref,
        relatedId: widget.parentTaskId ?? _draft.projectId,
      );
      if (domain == null || !mounted) return;
      final w = await ref.read(timeDomainsProvider.future);
      if (_draft.projectId != null &&
          await w.owner(_draft.projectId!) != domain)
        throw StateError('Project must be in the destination domain');
      final repo = w.tasks(domain);
      final task = _draft.toTaskForCreate(
        modelTypeId: schema.id,
        modelTypeName: schema.name,
      );
      final newId = await repo.create(
        task,
        parentTaskId: widget.parentTaskId,
        projectId: _draft.projectId,
      );
      w.remember(domain, [newId]);
      ref.invalidate(tasksForTodayProvider);
      ref.invalidate(allTasksProvider);
      ref.invalidate(calendarFeedProvider);
      ref.invalidate(calendarRefreshProvider);
      if (mounted) Navigator.of(context).pop(newId);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
        child: Column(
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
                      'New task',
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
                    onPressed: _saving || !_draft.canSave ? null : _save,
                    child: Text(
                      'Create',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _draft.canSave && !_saving
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
                  _label('TASK NAME'),
                  const SizedBox(height: 8),
                  CalendarDateTimeField(
                    label: 'Due',
                    value: _draft.dueAt,
                    onChanged: (v) => setState(() => _draft.dueAt = v),
                  ),
                  TextField(
                    controller: _nameCtl,
                    decoration: const InputDecoration(
                      hintText: 'What needs to be done?',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _label('PARENT PROJECT'),
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
                              color: AppColors.slate400,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _projectLabel(crumbs),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: _draft.projectId == null
                                      ? AppColors.slate400
                                      : AppColors.slate900,
                                ),
                              ),
                            ),
                            const Text(
                              'Select',
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
                  _label('NOTES (OPTIONAL)'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _notesCtl,
                    minLines: 3,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      hintText: 'Add any context…',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _label(String text) {
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
