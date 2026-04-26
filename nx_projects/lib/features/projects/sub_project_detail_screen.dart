import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nx_projects/core/layout/layout.dart';
import 'package:nx_projects/core/theme/app_theme.dart';
import 'package:nx_projects/domain/task/task.dart';
import 'package:nx_projects/domain/task/task_kind.dart';
import 'package:nx_projects/features/projects/projects_view_model.dart';
import 'package:nx_projects/features/projects/widgets/project_kind_section.dart';
import 'package:nx_projects/features/shared/widgets/task_row.dart';

class SubProjectDetailScreen extends ConsumerWidget {
  const SubProjectDetailScreen({
    super.key,
    required this.projectId,
    required this.subId,
    required this.onOpenTaskMenu,
  });

  final int projectId;
  final int subId;
  final void Function(BuildContext, WidgetRef, Task) onOpenTaskMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(
      subProjectTasksProvider((projectId: projectId, subId: subId)),
    );
    final feats = tasks.where((t) => t.kind == TaskKind.feat).toList();
    final bugs = tasks.where((t) => t.kind == TaskKind.bug).toList();
    final other = tasks.where((t) => t.kind == TaskKind.task).toList();

    return ListView(
      padding: NxLayout.contentPadding,
      children: [
        if (feats.isNotEmpty) ProjectKindSection(title: 'FEATURES', count: feats.length),
        for (final t in feats)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TaskRow(
              task: t,
              showBucket: true,
              showStatus: true,
              showCrumb: false,
              onMenu: () => onOpenTaskMenu(context, ref, t),
            ),
          ),
        if (bugs.isNotEmpty) ProjectKindSection(title: 'BUGS', count: bugs.length),
        for (final t in bugs)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TaskRow(
              task: t,
              showBucket: true,
              showStatus: true,
              showCrumb: false,
              onMenu: () => onOpenTaskMenu(context, ref, t),
            ),
          ),
        if (other.isNotEmpty) ProjectKindSection(title: 'TASKS', count: other.length),
        for (final t in other)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TaskRow(
              task: t,
              showBucket: true,
              showStatus: true,
              showCrumb: false,
              onMenu: () => onOpenTaskMenu(context, ref, t),
            ),
          ),
        if (tasks.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: Text(
                'No tasks in this subproject.',
                style: TextStyle(color: AppColors.dim, fontStyle: FontStyle.italic),
              ),
            ),
          ),
      ],
    );
  }
}
