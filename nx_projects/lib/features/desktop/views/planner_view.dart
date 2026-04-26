import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nx_projects/core/theme/app_theme.dart';
import 'package:nx_projects/domain/task/task.dart';
import 'package:nx_projects/features/desktop/widgets/sprint_cart.dart';
import 'package:nx_projects/features/filters/filter_sheet.dart';
import 'package:nx_projects/features/filters/filter_state_providers.dart';
import 'package:nx_projects/features/priority/priority_screen.dart';
import 'package:nx_projects/features/projects/projects_screen.dart';
import 'package:nx_projects/features/desktop/desktop_task_drawer_state.dart';
import 'package:nx_projects/features/desktop/widgets/reference_side_drawer.dart';
import 'package:nx_projects/features/shell/selection_providers.dart';
import 'package:nx_projects/features/shared/widgets/context_sheet.dart';
import 'package:nx_projects/features/task_edit/project_edit_sheet.dart';
import 'package:nx_projects/features/task_edit/task_edit_sheet.dart';
import 'package:nx_projects/features/task_view/task_view_drawer.dart';

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

    final drawerOpen = ref.watch(desktopTaskDrawerProvider) is! DesktopTaskDrawerClosed;

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
                onNewTask: () {
                  ref.read(desktopTaskDrawerProvider.notifier).newTask(
                        defaultProject: ref.read(selectedProjectIdProvider),
                        defaultSub: ref.read(selectedSubProjectIdProvider),
                      );
                },
              ),
            ),
            SprintCart(
              border: SprintCartBorder.left,
              onGoToSprintView: goSprint,
            ),
          ],
        ),
        if (drawerOpen) const Positioned.fill(child: _DesktopTaskDrawerLayer()),
      ],
    );
  }
}

class _DesktopTaskDrawerLayer extends ConsumerWidget {
  const _DesktopTaskDrawerLayer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(desktopTaskDrawerProvider);
    void close() => ref.read(desktopTaskDrawerProvider.notifier).close();

    return switch (s) {
      DesktopTaskDrawerClosed() => const SizedBox.shrink(),
      DesktopTaskViewing(:final taskId) => ReferenceSideDrawer(
          onClose: close,
          showHeader: false,
          widthMode: ReferenceSideDrawerWidth.wide,
          child: TaskViewDrawerContent(
            taskId: taskId,
            onClose: close,
          ),
        ),
      DesktopTaskEditing(:final task) => ReferenceSideDrawer(
          onClose: close,
          title: 'Edit task',
          widthMode: ReferenceSideDrawerWidth.narrow,
          child: TaskEditForm(
            key: ValueKey<Object>('e-${task.id}'),
            useReferenceDialog: false,
            sidePanel: true,
            onSidePanelClose: close,
            task: task,
            onSave: () {},
          ),
        ),
      DesktopTaskCreating(
        :final defaultProject,
        :final defaultSub,
        :final defaultBucket,
      ) =>
        ReferenceSideDrawer(
          onClose: close,
          title: 'New task',
          widthMode: ReferenceSideDrawerWidth.narrow,
          child: TaskEditForm(
            key: ObjectKey('new-$defaultProject-$defaultSub-$defaultBucket'),
            useReferenceDialog: false,
            sidePanel: true,
            onSidePanelClose: close,
            task: null,
            defaultProject: defaultProject,
            defaultSub: defaultSub,
            defaultBucket: defaultBucket,
            onSave: () {},
          ),
        ),
      DesktopProjectCreating() => ReferenceSideDrawer(
          onClose: close,
          title: 'New project',
          widthMode: ReferenceSideDrawerWidth.narrow,
          child: ProjectEditForm(
            useReferenceDialog: false,
            sidePanel: true,
            onSidePanelClose: close,
            onSave: () {},
          ),
        ),
    };
  }
}

class _PlannerLeftPane extends ConsumerStatefulWidget {
  const _PlannerLeftPane({
    required this.onOpenTaskMenu,
    required this.onNewProject,
    required this.onNewTask,
  });

  final void Function(BuildContext, WidgetRef, Task) onOpenTaskMenu;
  final VoidCallback onNewProject;
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
    final kind = ref.watch(filterKindProvider);
    final status = ref.watch(filterStatusProvider);
    final kindV = kind == 'all' ? 'All' : (kind == 'feat' ? 'Feature' : 'Bug');
    final stV = status == 'all'
        ? 'All'
        : (status == 'open' ? 'Open' : 'Done');

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
                    onChanged: (m) =>
                        ref.read(desktopPlannerModeProvider.notifier).setMode(m),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _HeadAddButton(
                        label: 'Project',
                        onPressed: widget.onNewProject,
                      ),
                      const SizedBox(width: 8),
                      _HeadAddButton(
                        label: 'Task',
                        onPressed: widget.onNewTask,
                      ),
                    ],
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _FilterChip(
                        lbl: 'Project',
                        value: 'All ▾',
                        onTap: () => showFilterSheet(context, ref),
                      ),
                      const SizedBox(width: 10),
                      _FilterChip(
                        lbl: 'Kind',
                        value: '$kindV ▾',
                        onTap: () => showFilterSheet(context, ref),
                      ),
                      const SizedBox(width: 10),
                      _FilterChip(
                        lbl: 'Status',
                        value: '$stV ▾',
                        onTap: () => showFilterSheet(context, ref),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 240, minWidth: 80),
                  child: TextField(
                    controller: _search,
                    onChanged: (s) => ref.read(searchQueryProvider.notifier).set(s),
                    style: const TextStyle(color: AppColors.text, fontSize: 12),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: AppColors.panel,
                      hintText: 'Search ideas…',
                      hintStyle: const TextStyle(color: AppColors.dim, fontSize: 12),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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

/// Planner header +Project / +Task: matches reference `.head-add-btn` padding
/// and hover; Material `OutlinedButton` added extra insets vs. the ref.
class _HeadAddButton extends StatefulWidget {
  const _HeadAddButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  State<_HeadAddButton> createState() => _HeadAddButtonState();
}

class _HeadAddButtonState extends State<_HeadAddButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onPressed,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: _hover ? AppColors.panel2 : AppColors.panel,
              border: Border.all(
                color: _hover ? AppColors.border2 : AppColors.border,
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '+',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    height: 1.0,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  widget.label,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.0,
                    color: AppColors.text,
                  ),
                ),
              ],
            ),
          ),
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
