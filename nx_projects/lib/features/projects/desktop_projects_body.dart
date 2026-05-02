import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nx_projects/core/theme/app_theme.dart';
import 'package:nx_projects/data/providers.dart';
import 'package:nx_projects/domain/task/task.dart';
import 'package:nx_projects/features/desktop/desktop_drawer_controller.dart';
import 'package:nx_projects/features/desktop/desktop_pane_task_scroller.dart';
import 'package:nx_projects/features/desktop/desktop_task_locator.dart';
import 'package:nx_projects/features/filters/filter_state_providers.dart';
import 'package:nx_projects/domain/task/task_bucket.dart';
import 'package:nx_projects/features/projects/projects_view_model.dart';
import 'package:nx_projects/features/projects/widgets/bucket_pill.dart';
import 'package:nx_projects/features/priority/widgets/inline_add_row.dart';
import 'package:nx_projects/features/shared/widgets/desktop_task_row.dart';

/// Desktop: full project / subproject tree with dense rows (`reference/desktop` pane-projects).
class DesktopProjectsBody extends ConsumerStatefulWidget {
  const DesktopProjectsBody({super.key, required this.onOpenTaskMenu});

  final void Function(BuildContext, WidgetRef, Task) onOpenTaskMenu;

  @override
  ConsumerState<DesktopProjectsBody> createState() =>
      _DesktopProjectsBodyState();
}

class _DesktopProjectsBodyState extends ConsumerState<DesktopProjectsBody> {
  /// Collapsed root projects (content hidden; header stays visible).
  final Set<int> _collapsedProjectIds = {};

  /// Collapsed subprojects (task list + inline add hidden; header stays visible).
  final Set<int> _collapsedSubProjectIds = {};

  ProviderSubscription<DesktopTaskLocatorState>? _locatorSub;
  final DesktopPaneTaskScroller _taskScroller = DesktopPaneTaskScroller();

  @override
  void initState() {
    super.initState();
    _locatorSub = ref.listenManual<DesktopTaskLocatorState>(
      desktopTaskLocatorProvider,
      (previous, next) {
        final effect = next.locateEffect;
        if (effect == null ||
            effect.surface != DesktopTaskLocatorSurface.planner ||
            previous?.locateEffect?.serial == effect.serial) {
          return;
        }
        _taskScroller.scrollToTask(effect.taskId, isMounted: () => mounted);
      },
    );
  }

  @override
  void dispose() {
    _locatorSub?.close();
    _taskScroller.dispose();
    super.dispose();
  }

  void _toggleProject(int id) {
    setState(() {
      if (_collapsedProjectIds.contains(id)) {
        _collapsedProjectIds.remove(id);
      } else {
        _collapsedProjectIds.add(id);
      }
    });
  }

  void _toggleSubProject(int id) {
    setState(() {
      if (_collapsedSubProjectIds.contains(id)) {
        _collapsedSubProjectIds.remove(id);
      } else {
        _collapsedSubProjectIds.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final q = ref.watch(searchQueryProvider);
    final searchActive = q.trim().isNotEmpty;
    final kindFilterActive = ref.watch(filterKindSetProvider).isNotEmpty;
    final statusFilterActive = ref.watch(filterStatusSetProvider).isNotEmpty;
    final taskFilterActive =
        searchActive || kindFilterActive || statusFilterActive;
    final selectedProjects = ref.watch(filterProjectIdsProvider);
    final sprints = ref.watch(sprintsListProvider);
    final locator = ref.watch(desktopTaskLocatorProvider);

    final roots = ref
        .watch(projectsListProvider)
        .where((p) => p.parentId == null)
        .toList();
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
      final expanded = !_collapsedProjectIds.contains(project.id);
      final subs = ref.watch(subProjectListRowsProvider(project.id));
      final allForProject = ref.watch(projectDetailTasksProvider(project.id));
      final selectedInTree =
          selectedProjects.contains(project.id) ||
          subs.any((s) => selectedProjects.contains(s.project.id));
      if (selectedProjects.isNotEmpty && !selectedInTree) continue;
      if (taskFilterActive && allForProject.isEmpty) continue;
      final directTasks = _sortByBucket(
        allForProject.where((t) => t.subProjectId == null).toList(),
      );
      var totalH = 0.0;
      for (final t in allForProject) {
        totalH += t.estimate;
      }
      final n = allForProject.length;
      final metaH = totalH % 1 == 0
          ? totalH.toInt().toString()
          : totalH.toString();
      final meta = n == 0 ? 'ideation' : '$n items · ${metaH}h est';

      children.add(
        Opacity(
          opacity: searchActive ? 0.5 : 1,
          child: _TreeProjectName(
            name: project.name,
            color: Color(project.color),
            meta: meta,
            isExpanded: expanded,
            onToggle: () => _toggleProject(project.id),
            onAdd: () => ref
                .read(desktopDrawerControllerProvider)
                .newTask(defaultProject: project.id),
          ),
        ),
      );
      if (!expanded) continue;

      final treeChildren = <Widget>[];
      for (final s in subs) {
        final subExpanded = !_collapsedSubProjectIds.contains(s.project.id);
        final tasks = _sortByBucket(
          ref.watch(
            subProjectTasksProvider((
              projectId: project.id,
              subId: s.project.id,
            )),
          ),
        );
        final subMetaH = s.hours % 1 == 0
            ? s.hours.toInt().toString()
            : '${s.hours}';
        if (selectedProjects.isNotEmpty &&
            !selectedProjects.contains(project.id) &&
            !selectedProjects.contains(s.project.id)) {
          continue;
        }
        treeChildren.add(
          Opacity(
            opacity: searchActive ? 0.5 : 1,
            child: _TreeSubName(
              name: s.project.name,
              meta: '${s.taskCount} items · ${subMetaH}h',
              isExpanded: subExpanded,
              onToggle: () => _toggleSubProject(s.project.id),
              onAdd: () => ref
                  .read(desktopDrawerControllerProvider)
                  .newTask(
                    defaultProject: project.id,
                    defaultSub: s.project.id,
                  ),
            ),
          ),
        );
        if (!subExpanded) continue;

        final subRows = <Widget>[];
        for (final t in tasks) {
          subRows.add(
            SizedBox(
              key: _taskScroller.rowKeyFor(t.id),
              child: DesktopTaskRow(
                task: t,
                rankLabel: rankLabelFor(t),
                sprintChipLabel: desktopSprintChipLabelForTask(t, sprints),
                crumb: DesktopBucketPill(task: t),
                isSearchMatch: _titleMatchesSearch(t, q),
                isLocated: locator.isHighlighted(t.id),
                onRowTap: () =>
                    ref.read(desktopDrawerControllerProvider).viewTask(t.id),
                onMenu: () => widget.onOpenTaskMenu(context, ref, t),
              ),
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
                  Opacity(
                    opacity: searchActive ? 0.5 : 1,
                    child: InlineAddRow(
                      label: 'Add to ${s.project.name}',
                      onTap: () => ref
                          .read(desktopDrawerControllerProvider)
                          .newTask(
                            defaultProject: project.id,
                            defaultSub: s.project.id,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      for (final t in directTasks) {
        treeChildren.add(
          SizedBox(
            key: _taskScroller.rowKeyFor(t.id),
            child: DesktopTaskRow(
              task: t,
              rankLabel: rankLabelFor(t),
              sprintChipLabel: desktopSprintChipLabelForTask(t, sprints),
              crumb: DesktopBucketPill(task: t),
              isSearchMatch: _titleMatchesSearch(t, q),
              isLocated: locator.isHighlighted(t.id),
              onRowTap: () =>
                  ref.read(desktopDrawerControllerProvider).viewTask(t.id),
              onMenu: () => widget.onOpenTaskMenu(context, ref, t),
            ),
          ),
        );
      }
      treeChildren.add(
        Opacity(
          opacity: searchActive ? 0.5 : 1,
          child: InlineAddRow(
            label: 'Add to ${project.name} (no subproject)',
            onTap: () => ref
                .read(desktopDrawerControllerProvider)
                .newTask(defaultProject: project.id),
          ),
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
    return SingleChildScrollView(
      controller: _taskScroller.controller,
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

bool _titleMatchesSearch(Task t, String q) {
  final s = q.trim().toLowerCase();
  if (s.isEmpty) return false;
  return t.title.toLowerCase().contains(s);
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
  final copy = [...tasks]
    ..sort((a, b) {
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
    required this.isExpanded,
    required this.onToggle,
    required this.onAdd,
  });

  final String name;
  final Color color;
  final String meta;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 8, 6, 4),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: IconButton(
              padding: EdgeInsets.zero,
              tooltip: isExpanded ? 'Collapse project' : 'Expand project',
              onPressed: onToggle,
              icon: Icon(
                isExpanded ? Icons.expand_more : Icons.chevron_right,
                size: 18,
                color: AppColors.muted,
              ),
            ),
          ),
          const SizedBox(width: 2),
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
    required this.isExpanded,
    required this.onToggle,
    required this.onAdd,
  });

  final String name;
  final String meta;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 8, 4, 4),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: IconButton(
              padding: EdgeInsets.zero,
              tooltip: isExpanded ? 'Collapse subproject' : 'Expand subproject',
              onPressed: onToggle,
              icon: Icon(
                isExpanded ? Icons.expand_more : Icons.chevron_right,
                size: 18,
                color: AppColors.muted,
              ),
            ),
          ),
          const SizedBox(width: 2),
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
