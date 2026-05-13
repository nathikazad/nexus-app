import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icon_pack/solar_icon_pack.dart';

import 'package:nx_time/core/theme/app_theme.dart';
import 'package:nx_time/features/tasks/projects_browse_page.dart';
import 'package:nx_time/features/tasks/projects_browse_view_model.dart';
import 'package:nx_time/features/tasks/task_create_page.dart';
import 'package:nx_time/features/tasks/task_pick_widgets.dart';
import 'package:nx_time/features/tasks/task_picker_view_model.dart';
import 'package:nx_time/features/tasks/task_view_models.dart';

/// Pick backlog tasks to pin to today (`reference/partials/view-task-picker.html`).
class TaskPickerPage extends ConsumerStatefulWidget {
  const TaskPickerPage({super.key});

  @override
  ConsumerState<TaskPickerPage> createState() => _TaskPickerPageState();
}

class _TaskPickerPageState extends ConsumerState<TaskPickerPage> {
  final Set<int> _selectedTaskIds = {};

  String _projectSubtitle(Map<int, String> crumbs, int? projectId) {
    if (projectId == null) return '';
    return crumbs[projectId] ?? 'Project $projectId';
  }

  @override
  Widget build(BuildContext context) {
    final yesterdayAsync = ref.watch(pickerUnfinishedYesterdayProvider);
    final recentAsync = ref.watch(pickerRecentTasksProvider);
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
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(SolarLinearIcons.arrowLeft, size: 22),
                    color: AppColors.slate600,
                  ),
                  const Expanded(
                    child: Text(
                      'Pick tasks for today',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                        color: AppColors.slate900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.slate200),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      SolarLinearIcons.magnifer,
                      size: 18,
                      color: AppColors.slate400,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Search all tasks…',
                      style: TextStyle(fontSize: 14, color: AppColors.slate400),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 100),
                children: [
                  _sectionStrip(
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppColors.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Unfinished from yesterday',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.slate500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  yesterdayAsync.when(
                    data: (tasks) => Column(
                      children: tasks
                          .map(
                            (t) => _taskRow(
                              title: t.name,
                              subtitle: _projectSubtitle(crumbs, t.projectId),
                              selected: _selectedTaskIds.contains(t.id),
                              onTap: () => setState(() {
                                if (!_selectedTaskIds.add(t.id)) {
                                  _selectedTaskIds.remove(t.id);
                                }
                              }),
                            ),
                          )
                          .toList(),
                    ),
                    loading: () => const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (e, _) => Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('$e'),
                    ),
                  ),
                  _sectionStrip(
                    child: const Text(
                      'Recently worked on',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.slate500,
                      ),
                    ),
                  ),
                  recentAsync.when(
                    data: (tasks) => Column(
                      children: tasks
                          .map(
                            (t) => _taskRow(
                              title: t.name,
                              subtitle: _projectSubtitle(crumbs, t.projectId),
                              selected: _selectedTaskIds.contains(t.id),
                              onTap: () => setState(() {
                                if (!_selectedTaskIds.add(t.id)) {
                                  _selectedTaskIds.remove(t.id);
                                }
                              }),
                            ),
                          )
                          .toList(),
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: () async {
                          final extra = await Navigator.of(context)
                              .push<Set<int>?>(
                                MaterialPageRoute(
                                  builder: (_) => const ProjectsBrowsePage(
                                    mode: ProjectsBrowseMode.pickTask,
                                  ),
                                ),
                              );
                          if (extra != null && mounted) {
                            setState(() => _selectedTaskIds.addAll(extra));
                          }
                        },
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
                              const Expanded(
                                child: Text(
                                  'Choose from projects',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.slate900,
                                  ),
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
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: TaskPickFooter(
        selectedLabel: '${_selectedTaskIds.length} selected',
        onDone: () {
          Navigator.of(context).pop<Set<int>>(Set<int>.from(_selectedTaskIds));
        },
        onNewTask: () async {
          final newId = await Navigator.of(context).push<int?>(
            MaterialPageRoute(builder: (_) => const TaskCreatePage()),
          );
          if (newId != null && mounted) {
            setState(() => _selectedTaskIds.add(newId));
          }
        },
      ),
    );
  }

  static Widget _sectionStrip({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
      decoration: const BoxDecoration(
        color: AppColors.slate50,
        border: Border(
          top: BorderSide(color: AppColors.slate100),
          bottom: BorderSide(color: AppColors.slate100),
        ),
      ),
      child: child,
    );
  }

  Widget _taskRow({
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.slate100)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: TaskSquareCheck(selected: selected),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.slate900,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.slate500,
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
