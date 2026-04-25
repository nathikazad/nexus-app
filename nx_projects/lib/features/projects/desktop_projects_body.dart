import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nx_projects/core/theme/app_theme.dart';
import 'package:nx_projects/data/providers.dart';
import 'package:nx_projects/domain/task/task.dart';
import 'package:nx_projects/domain/task/task_bucket.dart';
import 'package:nx_projects/features/projects/projects_view_model.dart';
import 'package:nx_projects/features/projects/widgets/bucket_pill.dart';
import 'package:nx_projects/features/priority/widgets/inline_add_row.dart';
import 'package:nx_projects/features/shared/widgets/desktop_task_row.dart';

/// Desktop: full project / subproject tree with dense rows (`reference/desktop` pane-projects).
class DesktopProjectsBody extends ConsumerWidget {
  const DesktopProjectsBody({super.key, required this.onOpenTaskMenu});

  final void Function(BuildContext, WidgetRef, Task) onOpenTaskMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roots = ref.watch(projectsListProvider).where((p) => p.parentId == null).toList();
    var rank = 0;

    String rankLabelFor(Task t) {
      if (t.bucket == TaskBucket.unsorted) {
        return '—';
      }
      rank += 1;
      return '$rank';
    }

    final children = <Widget>[];
    for (final project in roots) {
      final subs = ref.watch(subProjectListRowsProvider(project.id));
      final allForProject = ref.watch(projectDetailTasksProvider(project.id));
      final directTasks = _sortByBucket(
        allForProject.where((t) => t.subProjectId == null).toList(),
      );
      var totalH = 0.0;
      for (final t in allForProject) {
        totalH += t.estimate;
      }
      final n = allForProject.length;
      final metaH = totalH % 1 == 0 ? totalH.toInt().toString() : totalH.toString();
      final meta = n == 0 ? 'ideation' : '$n items · ${metaH}h est';

      children.add(
        _TreeProjectName(
          name: project.name,
          color: Color(project.color),
          meta: meta,
          onAdd: () {},
        ),
      );
      final treeChildren = <Widget>[];
      for (final s in subs) {
        final tasks = _sortByBucket(
          ref.watch(subProjectTasksProvider((projectId: project.id, subId: s.project.id))),
        );
        final subMetaH = s.hours % 1 == 0 ? s.hours.toInt().toString() : '${s.hours}';
        treeChildren.add(
          _TreeSubName(
            name: s.project.name,
            meta: '${s.taskCount} items · ${subMetaH}h',
            onAdd: () {},
          ),
        );
        final subRows = <Widget>[];
        for (final t in tasks) {
          subRows.add(
            DesktopTaskRow(
              task: t,
              rankLabel: rankLabelFor(t),
              sprintChipLabel: desktopSprintChipLabelForTask(t),
              crumb: DesktopBucketPill(task: t),
              onMenu: () => onOpenTaskMenu(context, ref, t),
            ),
          );
        }
        treeChildren.add(
          Padding(
            padding: const EdgeInsets.only(left: 10, top: 2, bottom: 4),
            child: Container(
              decoration: const BoxDecoration(
                border: Border(left: BorderSide(color: AppColors.border)),
              ),
              padding: const EdgeInsets.only(left: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...subRows,
                  InlineAddRow(
                    label: 'Add to ${s.project.name}',
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),
        );
      }
      for (final t in directTasks) {
        treeChildren.add(
          DesktopTaskRow(
            task: t,
            rankLabel: rankLabelFor(t),
            sprintChipLabel: desktopSprintChipLabelForTask(t),
            crumb: DesktopBucketPill(task: t),
            onMenu: () => onOpenTaskMenu(context, ref, t),
          ),
        );
      }
      treeChildren.add(
        InlineAddRow(
          label: 'Add to ${project.name} (no subproject)',
          onTap: () {},
        ),
      );

      children.add(
        Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Container(
            decoration: const BoxDecoration(
              border: Border(left: BorderSide(color: AppColors.border)),
            ),
            padding: const EdgeInsets.only(left: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: treeChildren,
            ),
          ),
        ),
      );
    }
    children.add(
      const Padding(
        padding: EdgeInsets.fromLTRB(4, 16, 4, 0),
        child: Text(
          'Crumb column shows priority bucket. Rows are ordered by bucket within each group.',
          style: TextStyle(fontSize: 11, color: AppColors.dim, height: 1.6),
        ),
      ),
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(6, 0, 20, 40),
      children: children,
    );
  }
}

int _bucketIx(TaskBucket b) {
  return switch (b) {
    TaskBucket.now => 0,
    TaskBucket.next => 1,
    TaskBucket.later => 2,
    TaskBucket.someday => 3,
    TaskBucket.unsorted => 4,
  };
}

List<Task> _sortByBucket(List<Task> tasks) {
  final copy = [...tasks]..sort((a, b) {
        final c = _bucketIx(a.bucket).compareTo(_bucketIx(b.bucket));
        if (c != 0) return c;
        return a.title.compareTo(b.title);
      });
  return copy;
}

class _TreeProjectName extends StatelessWidget {
  const _TreeProjectName({
    required this.name,
    required this.color,
    required this.meta,
    required this.onAdd,
  });

  final String name;
  final Color color;
  final String meta;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
            ),
          ),
          Text(
            meta,
            style: const TextStyle(fontSize: 11, color: AppColors.muted),
          ),
          _HoverAdd(onTap: onAdd),
        ],
      ),
    );
  }
}

class _TreeSubName extends StatelessWidget {
  const _TreeSubName({
    required this.name,
    required this.meta,
    required this.onAdd,
  });

  final String name;
  final String meta;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
      child: Row(
        children: [
          const Text('▾ ', style: TextStyle(fontSize: 12, color: AppColors.muted)),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.muted,
              ),
            ),
          ),
          Text(meta, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
          _HoverAdd(onTap: onAdd),
        ],
      ),
    );
  }
}

class _HoverAdd extends StatefulWidget {
  const _HoverAdd({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_HoverAdd> createState() => _HoverAddState();
}

class _HoverAddState extends State<_HoverAdd> {
  bool _h = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: Opacity(
        opacity: _h ? 1 : 0,
        child: IconButton(
          onPressed: widget.onTap,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          icon: const Icon(Icons.add, size: 16, color: AppColors.dim),
        ),
      ),
    );
  }
}
