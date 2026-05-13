import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icon_pack/solar_icon_pack.dart';

import 'package:nx_time/core/theme/app_theme.dart';
import 'package:nx_time/features/tasks/projects_browse_view_model.dart';
import 'package:nx_time/features/tasks/task_create_page.dart';
import 'package:nx_time/features/tasks/task_detail_page.dart';
import 'package:nx_time/features/tasks/task_pick_widgets.dart';
import 'package:nx_time/features/tasks/project_drill_view_model.dart';

/// Project drill-down: sub-projects + direct tasks (`page-project-drill-down` / deep).
class ProjectDrillPage extends ConsumerStatefulWidget {
  const ProjectDrillPage({
    super.key,
    required this.projectId,
    this.mode = ProjectsBrowseMode.browse,
  });

  final int projectId;
  final ProjectsBrowseMode mode;

  @override
  ConsumerState<ProjectDrillPage> createState() => _ProjectDrillPageState();
}

class _ProjectDrillPageState extends ConsumerState<ProjectDrillPage> {
  final Set<int> _selectedTaskIds = {};

  @override
  Widget build(BuildContext context) {
    final projectAsync = ref.watch(projectByIdProvider(widget.projectId));
    final subsAsync = ref.watch(subProjectsProvider(widget.projectId));
    final tasksAsync = ref.watch(tasksInProjectProvider(widget.projectId));
    final crumbsAsync = ref.watch(
      breadcrumbForProjectProvider(widget.projectId),
    );

    final showPickChrome = widget.mode == ProjectsBrowseMode.pickTask;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: projectAsync.when(
          data: (project) {
            if (project == null) {
              return const Center(child: Text('Project not found'));
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(SolarLinearIcons.arrowLeft, size: 22),
                        color: AppColors.slate600,
                      ),
                      Expanded(
                        child: Text(
                          project.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                            color: AppColors.slate900,
                          ),
                        ),
                      ),
                      if (widget.mode == ProjectsBrowseMode.pickProject)
                        TextButton(
                          onPressed: () =>
                              Navigator.of(context).pop<int>(widget.projectId),
                          child: const Text(
                            'Select',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: crumbsAsync.when(
                    data: (chain) {
                      if (chain.length <= 1) return const SizedBox.shrink();
                      return Wrap(
                        spacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          for (var i = 0; i < chain.length; i++) ...[
                            if (i > 0)
                              Text(
                                '›',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.slate300,
                                ),
                              ),
                            Text(
                              chain[i].name,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.accent,
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.only(bottom: showPickChrome ? 100 : 24),
                    children: [
                      _sectionLabel('Sub-projects'),
                      subsAsync.when(
                        data: (subs) {
                          if (subs.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.fromLTRB(20, 8, 20, 8),
                              child: Text(
                                'No sub-projects',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.slate400,
                                ),
                              ),
                            );
                          }
                          return Column(
                            children: subs.map((s) {
                              return _navRow(
                                title: s.name,
                                subtitle:
                                    '${s.childProjectIds.length} sub-projects',
                                onTap: () async {
                                  if (widget.mode ==
                                      ProjectsBrowseMode.pickProject) {
                                    final picked = await Navigator.of(context)
                                        .push<int?>(
                                          MaterialPageRoute(
                                            builder: (_) => ProjectDrillPage(
                                              projectId: s.id,
                                              mode: ProjectsBrowseMode
                                                  .pickProject,
                                            ),
                                          ),
                                        );
                                    if (!context.mounted) return;
                                    if (picked != null) {
                                      Navigator.of(context).pop<int>(picked);
                                    }
                                    return;
                                  }
                                  final result = await Navigator.of(context)
                                      .push<Set<int>?>(
                                        MaterialPageRoute(
                                          builder: (_) => ProjectDrillPage(
                                            projectId: s.id,
                                            mode: widget.mode,
                                          ),
                                        ),
                                      );
                                  if (widget.mode ==
                                          ProjectsBrowseMode.pickTask &&
                                      result != null &&
                                      mounted) {
                                    setState(
                                      () => _selectedTaskIds.addAll(result),
                                    );
                                  }
                                },
                              );
                            }).toList(),
                          );
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                      _sectionLabel('Direct tasks'),
                      tasksAsync.when(
                        data: (tasks) {
                          if (tasks.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.fromLTRB(20, 8, 20, 8),
                              child: Text(
                                'No tasks in this project',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.slate400,
                                ),
                              ),
                            );
                          }
                          return Column(
                            children: tasks.map((t) {
                              final selected = _selectedTaskIds.contains(t.id);
                              return Material(
                                color: Colors.white,
                                child: InkWell(
                                  onTap: () {
                                    if (showPickChrome) {
                                      setState(() {
                                        if (!_selectedTaskIds.add(t.id)) {
                                          _selectedTaskIds.remove(t.id);
                                        }
                                      });
                                    } else {
                                      Navigator.of(context).push<void>(
                                        MaterialPageRoute<void>(
                                          builder: (_) =>
                                              TaskDetailPage(taskId: t.id),
                                        ),
                                      );
                                    }
                                  },
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: AppColors.slate100,
                                        ),
                                      ),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 10,
                                    ),
                                    child: Row(
                                      children: [
                                        if (showPickChrome) ...[
                                          TaskSquareCheck(selected: selected),
                                          const SizedBox(width: 10),
                                        ],
                                        Expanded(
                                          child: Text(
                                            t.name,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: AppColors.slate900,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          );
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
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
      bottomNavigationBar: showPickChrome
          ? TaskPickFooter(
              selectedLabel: '${_selectedTaskIds.length} selected',
              onDone: () => Navigator.of(
                context,
              ).pop<Set<int>>(Set<int>.from(_selectedTaskIds)),
              onNewTask: () async {
                await Navigator.of(context).push<int?>(
                  MaterialPageRoute(
                    builder: (_) =>
                        TaskCreatePage(initialProjectId: widget.projectId),
                  ),
                );
                ref.invalidate(tasksInProjectProvider(widget.projectId));
              },
            )
          : null,
    );
  }

  static Widget _sectionLabel(String text) {
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
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.slate500,
        ),
      ),
    );
  }

  static Widget _navRow({
    required String title,
    required String subtitle,
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
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
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.slate500,
                      ),
                    ),
                  ],
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
    );
  }
}
