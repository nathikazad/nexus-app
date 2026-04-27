import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nx_projects/core/theme/app_theme.dart';
import 'package:nx_projects/data/providers.dart';
import 'package:nx_projects/domain/project/project.dart';
import 'package:nx_projects/domain/task/task.dart';
import 'package:nx_projects/features/desktop/widgets/sprint_cart.dart';
import 'package:nx_projects/features/filters/filter_state_providers.dart';
import 'package:nx_projects/features/priority/priority_screen.dart';
import 'package:nx_projects/features/projects/projects_screen.dart';
import 'package:nx_projects/features/desktop/desktop_task_drawer_state.dart';
import 'package:nx_projects/features/desktop/widgets/desktop_drawer_layer.dart';
import 'package:nx_projects/features/shell/selection_providers.dart';
import 'package:nx_projects/features/shared/widgets/context_sheet.dart';

String _plannerKindMenuLabel(String k) {
  return switch (k) {
    'feat' => 'Feature',
    'bug' => 'Bug',
    'task' => 'Task',
    _ => k,
  };
}

String _plannerStatusMenuLabel(String s) {
  return switch (s) {
    'todo' => 'To do',
    'doing' => 'Doing',
    'done' => 'Done',
    'blocked' => 'Blocked',
    _ => s,
  };
}

String _plannerFilterChipValue(Set<String> selected) {
  if (selected.isEmpty) {
    return 'All ▾';
  }
  if (selected.length == 1) {
    return '1 selected ▾';
  }
  return '${selected.length} selected ▾';
}

/// `reference/desktop/` Planner: left backlog + right sprint cart.
class PlannerView extends ConsumerWidget {
  const PlannerView({super.key});

  void _openTaskMenu(BuildContext context, WidgetRef ref, Task t) {
    showTaskContextSheet(context, ref, task: t, onAfterChange: () {});
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void goSprint() {
      ref.read(desktopViewIndexProvider.notifier).setView(1);
    }

    final drawerOpen =
        ref.watch(desktopTaskDrawerProvider) is! DesktopTaskDrawerClosed;

    return Stack(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _PlannerLeftPane(
                onOpenTaskMenu: _openTaskMenu,
                onNewProject: () {
                  ref.read(desktopTaskDrawerProvider.notifier).newProject();
                },
                onNewSprint: () {
                  ref.read(desktopTaskDrawerProvider.notifier).newSprint();
                },
                onNewTask: () {
                  ref
                      .read(desktopTaskDrawerProvider.notifier)
                      .newTask(
                        defaultProject: ref.read(selectedProjectIdProvider),
                        defaultSub: ref.read(selectedSubProjectIdProvider),
                      );
                },
              ),
            ),
            SprintCart(
              border: SprintCartBorder.left,
              surface: SprintCartSurface.planner,
              onFooter: goSprint,
            ),
          ],
        ),
        if (drawerOpen) const Positioned.fill(child: DesktopDrawerLayer()),
      ],
    );
  }
}

class _PlannerLeftPane extends ConsumerStatefulWidget {
  const _PlannerLeftPane({
    required this.onOpenTaskMenu,
    required this.onNewProject,
    required this.onNewSprint,
    required this.onNewTask,
  });

  final void Function(BuildContext, WidgetRef, Task) onOpenTaskMenu;
  final VoidCallback onNewProject;
  final VoidCallback onNewSprint;
  final VoidCallback onNewTask;

  @override
  ConsumerState<_PlannerLeftPane> createState() => _PlannerLeftPaneState();
}

class _PlannerLeftPaneState extends ConsumerState<_PlannerLeftPane> {
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: ref.read(searchQueryProvider));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(desktopPlannerModeProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Planner',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _PaneToggle(
                    mode: mode,
                    onChanged: (m) => ref
                        .read(desktopPlannerModeProvider.notifier)
                        .setMode(m),
                  ),
                  _PlannerAddMenuButton(
                    onNewProject: widget.onNewProject,
                    onNewTask: widget.onNewTask,
                    onNewSprint: widget.onNewSprint,
                  ),
                ],
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const _ProjectFilterChip(),
                        const SizedBox(width: 10),
                        const _KindFilterChip(),
                        const SizedBox(width: 10),
                        const _StatusFilterChip(),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 240,
                child: TextField(
                  controller: _search,
                  onChanged: (s) =>
                      ref.read(searchQueryProvider.notifier).set(s),
                  style: const TextStyle(color: AppColors.text, fontSize: 12),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.panel,
                    hintText: 'Search ideas…',
                    hintStyle: const TextStyle(
                      color: AppColors.dim,
                      fontSize: 12,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(6)),
                      borderSide: BorderSide(color: AppColors.accent),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.border),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: mode == 0
                ? ProjectsScreen(onOpenTaskMenu: widget.onOpenTaskMenu)
                : PriorityScreen(onOpenTaskMenu: widget.onOpenTaskMenu),
          ),
        ),
      ],
    );
  }
}

class _PaneToggle extends StatelessWidget {
  const _PaneToggle({required this.mode, required this.onChanged});

  final int mode;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SegBtn(
            label: 'Projects',
            selected: mode == 0,
            onTap: () => onChanged(0),
          ),
          _SegBtn(
            label: 'Priority',
            selected: mode == 1,
            onTap: () => onChanged(1),
          ),
        ],
      ),
    );
  }
}

class _SegBtn extends StatelessWidget {
  const _SegBtn({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.panel3 : Colors.transparent,
      borderRadius: BorderRadius.circular(5),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(5),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: selected ? AppColors.text : AppColors.muted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact creation palette for planner-level objects.
class _PlannerAddMenuButton extends StatefulWidget {
  const _PlannerAddMenuButton({
    required this.onNewProject,
    required this.onNewTask,
    required this.onNewSprint,
  });

  final VoidCallback onNewProject;
  final VoidCallback onNewTask;
  final VoidCallback onNewSprint;

  @override
  State<_PlannerAddMenuButton> createState() => _PlannerAddMenuButtonState();
}

class _PlannerAddMenuButtonState extends State<_PlannerAddMenuButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      alignmentOffset: const Offset(-186, 6),
      style: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(AppColors.panel),
        elevation: const WidgetStatePropertyAll(12),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 6)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: AppColors.border),
          ),
        ),
        minimumSize: const WidgetStatePropertyAll(Size(210, 0)),
      ),
      menuChildren: [
        _PlannerAddMenuItem(
          icon: Icons.folder_open_outlined,
          title: 'Project',
          subtitle: 'Create a root project',
          onPressed: widget.onNewProject,
        ),
        _PlannerAddMenuItem(
          icon: Icons.check_circle_outline,
          title: 'Task',
          subtitle: 'Add work to the backlog',
          onPressed: widget.onNewTask,
        ),
        _PlannerAddMenuItem(
          icon: Icons.calendar_month_outlined,
          title: 'Sprint',
          subtitle: 'Plan a new sprint',
          onPressed: widget.onNewSprint,
        ),
      ],
      builder: (context, controller, child) {
        return MouseRegion(
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                if (controller.isOpen) {
                  controller.close();
                } else {
                  controller.open();
                }
              },
              borderRadius: BorderRadius.circular(6),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: _hover ? AppColors.panel2 : AppColors.panel,
                  border: Border.all(
                    color: _hover ? AppColors.border2 : AppColors.border,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.add,
                  size: 18,
                  color: AppColors.accent,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PlannerAddMenuItem extends StatelessWidget {
  const _PlannerAddMenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return MenuItemButton(
      onPressed: onPressed,
      style: ButtonStyle(
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        ),
        backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
        overlayColor: WidgetStatePropertyAll(
          AppColors.panel3.withValues(alpha: 0.55),
        ),
        foregroundColor: const WidgetStatePropertyAll(AppColors.text),
      ),
      child: SizedBox(
        width: 190,
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.panel3,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(icon, size: 16, color: AppColors.accent),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.1,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      height: 1.1,
                      color: AppColors.dim,
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
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.lbl, required this.value, this.onTap});

  final String lbl;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.panel,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text.rich(
            TextSpan(
              style: const TextStyle(fontSize: 12, color: AppColors.text),
              children: [
                TextSpan(
                  text: '$lbl ',
                  style: const TextStyle(color: AppColors.muted),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProjectFilterChip extends ConsumerStatefulWidget {
  const _ProjectFilterChip();

  @override
  ConsumerState<_ProjectFilterChip> createState() => _ProjectFilterChipState();
}

class _ProjectFilterChipState extends ConsumerState<_ProjectFilterChip> {
  final MenuController _menu = MenuController();

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(filterProjectIdsProvider);
    final label = selected.isEmpty
        ? 'All ▾'
        : selected.length == 1
        ? '1 selected ▾'
        : '${selected.length} selected ▾';

    return MenuAnchor(
      controller: _menu,
      alignmentOffset: const Offset(0, 6),
      style: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(AppColors.panel),
        elevation: const WidgetStatePropertyAll(8),
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: AppColors.border),
          ),
        ),
      ),
      menuChildren: const [_ProjectFilterMenu()],
      builder: (context, controller, child) {
        return _FilterChip(
          lbl: 'Project',
          value: label,
          onTap: () {
            if (controller.isOpen) {
              controller.close();
            } else {
              controller.open();
            }
          },
        );
      },
    );
  }
}

class _KindFilterChip extends ConsumerStatefulWidget {
  const _KindFilterChip();

  @override
  ConsumerState<_KindFilterChip> createState() => _KindFilterChipState();
}

class _KindFilterChipState extends ConsumerState<_KindFilterChip> {
  final MenuController _menu = MenuController();

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(filterKindSetProvider);
    final label = _plannerFilterChipValue(selected);

    return MenuAnchor(
      controller: _menu,
      alignmentOffset: const Offset(0, 6),
      style: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(AppColors.panel),
        elevation: const WidgetStatePropertyAll(8),
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: AppColors.border),
          ),
        ),
      ),
      menuChildren: const [_KindFilterMenu()],
      builder: (context, controller, child) {
        return _FilterChip(
          lbl: 'Kind',
          value: label,
          onTap: () {
            if (controller.isOpen) {
              controller.close();
            } else {
              controller.open();
            }
          },
        );
      },
    );
  }
}

class _StatusFilterChip extends ConsumerStatefulWidget {
  const _StatusFilterChip();

  @override
  ConsumerState<_StatusFilterChip> createState() => _StatusFilterChipState();
}

class _StatusFilterChipState extends ConsumerState<_StatusFilterChip> {
  final MenuController _menu = MenuController();

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(filterStatusSetProvider);
    final label = _plannerFilterChipValue(selected);

    return MenuAnchor(
      controller: _menu,
      alignmentOffset: const Offset(0, 6),
      style: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(AppColors.panel),
        elevation: const WidgetStatePropertyAll(8),
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: AppColors.border),
          ),
        ),
      ),
      menuChildren: const [_StatusFilterMenu()],
      builder: (context, controller, child) {
        return _FilterChip(
          lbl: 'Status',
          value: label,
          onTap: () {
            if (controller.isOpen) {
              controller.close();
            } else {
              controller.open();
            }
          },
        );
      },
    );
  }
}

class _ProjectFilterMenu extends ConsumerWidget {
  const _ProjectFilterMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectsListProvider);
    final selected = ref.watch(filterProjectIdsProvider);
    final roots = projects.where((p) => p.parentId == null).toList();

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 420, minWidth: 320),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _FilterMenuActionRow(
              label: 'All projects',
              selected: selected.isEmpty,
              onTap: () => ref.read(filterProjectIdsProvider.notifier).clear(),
            ),
            _FilterMenuActionRow(
              label: 'Select all',
              selected:
                  selected.length == projects.length && projects.isNotEmpty,
              onTap: () {
                final allIds = projects.map((p) => p.id);
                ref.read(filterProjectIdsProvider.notifier).setAll(allIds);
              },
            ),
            const Divider(height: 1, color: AppColors.border),
            for (final root in roots) ...[
              _ProjectFilterRow(
                project: root,
                selected: selected.contains(root.id),
                onTap: () =>
                    ref.read(filterProjectIdsProvider.notifier).toggle(root.id),
              ),
              for (final sub in projects.where((p) => p.parentId == root.id))
                _ProjectFilterRow(
                  project: sub,
                  selected: selected.contains(sub.id),
                  indent: true,
                  onTap: () => ref
                      .read(filterProjectIdsProvider.notifier)
                      .toggle(sub.id),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _KindFilterMenu extends ConsumerWidget {
  const _KindFilterMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(filterKindSetProvider);
    final all = FilterKindSet.allKindKeys;
    final allSelected =
        selected.length == all.length && all.every((k) => selected.contains(k));

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 360, minWidth: 240),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _FilterMenuActionRow(
              label: 'All kinds',
              selected: selected.isEmpty,
              onTap: () => ref.read(filterKindSetProvider.notifier).clear(),
            ),
            _FilterMenuActionRow(
              label: 'Select all',
              selected: allSelected,
              onTap: () => ref.read(filterKindSetProvider.notifier).setAll(),
            ),
            const Divider(height: 1, color: AppColors.border),
            for (final k in const ['feat', 'bug', 'task'])
              _FilterMenuActionRow(
                label: _plannerKindMenuLabel(k),
                selected: selected.contains(k),
                onTap: () => ref.read(filterKindSetProvider.notifier).toggle(k),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusFilterMenu extends ConsumerWidget {
  const _StatusFilterMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(filterStatusSetProvider);
    final all = FilterStatusSet.allStatusKeys;
    final allSelected =
        selected.length == all.length && all.every((k) => selected.contains(k));

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 400, minWidth: 240),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _FilterMenuActionRow(
              label: 'All statuses',
              selected: selected.isEmpty,
              onTap: () => ref.read(filterStatusSetProvider.notifier).clear(),
            ),
            _FilterMenuActionRow(
              label: 'Select all',
              selected: allSelected,
              onTap: () => ref.read(filterStatusSetProvider.notifier).setAll(),
            ),
            const Divider(height: 1, color: AppColors.border),
            for (final s in const ['todo', 'doing', 'done', 'blocked'])
              _FilterMenuActionRow(
                label: _plannerStatusMenuLabel(s),
                selected: selected.contains(s),
                onTap: () =>
                    ref.read(filterStatusSetProvider.notifier).toggle(s),
              ),
          ],
        ),
      ),
    );
  }
}

class _FilterMenuActionRow extends StatelessWidget {
  const _FilterMenuActionRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(
              selected ? Icons.check_box : Icons.check_box_outline_blank,
              size: 18,
              color: selected ? AppColors.accent : AppColors.dim,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: selected ? AppColors.text : AppColors.muted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectFilterRow extends StatelessWidget {
  const _ProjectFilterRow({
    required this.project,
    required this.selected,
    required this.onTap,
    this.indent = false,
  });

  final Project project;
  final bool selected;
  final VoidCallback onTap;
  final bool indent;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Row(
          children: [
            SizedBox(width: indent ? 22 : 0),
            Icon(
              selected ? Icons.check_box : Icons.check_box_outline_blank,
              size: 18,
              color: selected ? AppColors.accent : AppColors.dim,
            ),
            const SizedBox(width: 10),
            if (!indent) ...[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Color(project.color),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
            ] else ...[
              const Icon(
                Icons.subdirectory_arrow_right,
                size: 14,
                color: AppColors.dim,
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                project.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: indent ? AppColors.muted : AppColors.text,
                  fontWeight: indent ? FontWeight.w400 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
