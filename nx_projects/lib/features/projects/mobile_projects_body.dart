import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nx_projects/core/layout/layout.dart';
import 'package:nx_projects/domain/task/task.dart';
import 'package:nx_projects/features/projects/project_detail_screen.dart';
import 'package:nx_projects/features/projects/projects_view_model.dart';
import 'package:nx_projects/features/projects/sub_project_detail_screen.dart';
import 'package:nx_projects/features/projects/widgets/project_row.dart';
import 'package:nx_projects/features/shell/selection_providers.dart';

/// Mobile: project list → project detail → subproject detail.
class MobileProjectsBody extends ConsumerWidget {
  const MobileProjectsBody({super.key, required this.onOpenTaskMenu});

  final void Function(BuildContext, WidgetRef, Task) onOpenTaskMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pid = ref.watch(selectedProjectIdProvider);
    final sid = ref.watch(selectedSubProjectIdProvider);
    if (pid == null) {
      return _ProjectList(
        onPick: (id) {
          ref.read(selectedProjectIdProvider.notifier).set(id);
          ref.read(selectedSubProjectIdProvider.notifier).set(null);
        },
      );
    }
    if (sid == null) {
      return ProjectDetailScreen(
        projectId: pid,
        onPickSub: (subId) {
          ref.read(selectedSubProjectIdProvider.notifier).set(subId);
        },
        onOpenTaskMenu: onOpenTaskMenu,
      );
    }
    return SubProjectDetailScreen(
      projectId: pid,
      subId: sid,
      onOpenTaskMenu: onOpenTaskMenu,
    );
  }
}

class _ProjectList extends ConsumerWidget {
  const _ProjectList({required this.onPick});

  final void Function(String id) onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(projectListRowsProvider);
    return ListView.builder(
      padding: NxLayout.contentPadding,
      itemCount: rows.length,
      itemBuilder: (c, i) {
        final r = rows[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ProjectRow(
            name: r.project.name,
            color: Color(r.project.color),
            count: r.taskCount,
            hours: r.hours,
            onTap: () => onPick(r.project.id),
          ),
        );
      },
    );
  }
}
