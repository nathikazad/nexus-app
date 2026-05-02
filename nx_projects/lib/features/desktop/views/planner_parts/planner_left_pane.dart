part of '../planner_view.dart';

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
                        .read(desktopNavigationControllerProvider)
                        .showPlannerPane(DesktopPlannerPane.values[m]),
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
