part of '../planner_view.dart';

class _PlannerLeftPane extends ConsumerStatefulWidget {
  _PlannerLeftPane({
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
          padding: EdgeInsets.fromLTRB(20, 14, 20, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Planner',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: context.colors.text,
                ),
              ),
              SizedBox(height: 10),
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
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: context.colors.border)),
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
                        _ProjectFilterChip(),
                        SizedBox(width: 10),
                        _KindFilterChip(),
                        SizedBox(width: 10),
                        _StatusFilterChip(),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: 10),
              SizedBox(
                width: 240,
                child: TextField(
                  controller: _search,
                  onChanged: (s) =>
                      ref.read(searchQueryProvider.notifier).set(s),
                  style: TextStyle(color: context.colors.text, fontSize: 12),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: context.colors.panel,
                    hintText: 'Search ideas…',
                    hintStyle: TextStyle(
                      color: context.colors.dim,
                      fontSize: 12,
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: context.colors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: context.colors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(6)),
                      borderSide: BorderSide(color: context.colors.accent),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: context.colors.border),
        Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
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
  _PaneToggle({required this.mode, required this.onChanged});

  final int mode;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: context.colors.panel,
        border: Border.all(color: context.colors.border),
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
  _SegBtn({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? context.colors.panel3 : Colors.transparent,
      borderRadius: BorderRadius.circular(5),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(5),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: selected ? context.colors.text : context.colors.muted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact creation palette for planner-level objects.
