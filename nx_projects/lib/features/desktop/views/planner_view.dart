import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nx_projects/core/theme/app_theme.dart';
import 'package:nx_projects/domain/task/task.dart';
import 'package:nx_projects/features/desktop/widgets/sprint_cart.dart';
import 'package:nx_projects/features/filters/filter_sheet.dart';
import 'package:nx_projects/features/filters/filter_state_providers.dart';
import 'package:nx_projects/features/priority/priority_screen.dart';
import 'package:nx_projects/features/projects/projects_screen.dart';
import 'package:nx_projects/features/shell/selection_providers.dart';
import 'package:nx_projects/features/shared/widgets/context_sheet.dart';
import 'package:nx_projects/features/task_edit/project_edit_sheet.dart';
import 'package:nx_projects/features/task_edit/task_edit_sheet.dart';

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

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: _PlannerLeftPane(
            onOpenTaskMenu: _openTaskMenu,
            onNewProject: () => showProjectEditSheet(context, ref, onSave: () {}),
            onNewTask: () {
              final pid = ref.read(selectedProjectIdProvider);
              final sid = ref.read(selectedSubProjectIdProvider);
              showTaskEditSheet(
                context,
                ref,
                defaultProject: pid,
                defaultSub: sid,
                onSave: () {},
              );
            },
          ),
        ),
        SprintCart(
          border: SprintCartBorder.left,
          onGoToSprintView: goSprint,
        ),
      ],
    );
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
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _PaneToggle(
                    mode: mode,
                    onChanged: (m) =>
                        ref.read(desktopPlannerModeProvider.notifier).setMode(m),
                  ),
                  _HeadAddButton(
                    label: 'Project',
                    onPressed: widget.onNewProject,
                  ),
                  _HeadAddButton(
                    label: 'Task',
                    onPressed: widget.onNewTask,
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
                ? PriorityScreen(onOpenTaskMenu: widget.onOpenTaskMenu)
                : ProjectsScreen(onOpenTaskMenu: widget.onOpenTaskMenu),
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
            label: 'Priority',
            selected: mode == 0,
            onTap: () => onChanged(0),
          ),
          _SegBtn(
            label: 'Projects',
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

class _HeadAddButton extends StatelessWidget {
  const _HeadAddButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.text,
        side: const BorderSide(color: AppColors.border),
        backgroundColor: AppColors.panel,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
            ),
          ),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
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
