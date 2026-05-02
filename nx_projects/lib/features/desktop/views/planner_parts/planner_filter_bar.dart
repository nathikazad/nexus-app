part of '../planner_view.dart';

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

class _FilterChip extends StatelessWidget {
  _FilterChip({required this.lbl, required this.value, this.onTap});

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
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: context.colors.panel,
            border: Border.all(color: context.colors.border),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text.rich(
            TextSpan(
              style: TextStyle(fontSize: 12, color: context.colors.text),
              children: [
                TextSpan(
                  text: '$lbl ',
                  style: TextStyle(color: context.colors.muted),
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
  _ProjectFilterChip();

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
      alignmentOffset: Offset(0, 6),
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(context.colors.panel),
        elevation: WidgetStatePropertyAll(8),
        padding: WidgetStatePropertyAll(EdgeInsets.zero),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: context.colors.border),
          ),
        ),
      ),
      menuChildren: [_ProjectFilterMenu()],
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
  _KindFilterChip();

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
      alignmentOffset: Offset(0, 6),
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(context.colors.panel),
        elevation: WidgetStatePropertyAll(8),
        padding: WidgetStatePropertyAll(EdgeInsets.zero),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: context.colors.border),
          ),
        ),
      ),
      menuChildren: [_KindFilterMenu()],
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
  _StatusFilterChip();

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
      alignmentOffset: Offset(0, 6),
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(context.colors.panel),
        elevation: WidgetStatePropertyAll(8),
        padding: WidgetStatePropertyAll(EdgeInsets.zero),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: context.colors.border),
          ),
        ),
      ),
      menuChildren: [_StatusFilterMenu()],
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
  _ProjectFilterMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectsListProvider);
    final selected = ref.watch(filterProjectIdsProvider);
    final roots = projects.where((p) => p.parentId == null).toList();

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: 420, minWidth: 320),
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(vertical: 6),
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
            Divider(height: 1, color: context.colors.border),
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
  _KindFilterMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(filterKindSetProvider);
    final all = FilterKindSet.allKindKeys;
    final allSelected =
        selected.length == all.length && all.every((k) => selected.contains(k));

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: 360, minWidth: 240),
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(vertical: 6),
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
            Divider(height: 1, color: context.colors.border),
            for (final k in ['feat', 'bug', 'task'])
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
  _StatusFilterMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(filterStatusSetProvider);
    final all = FilterStatusSet.allStatusKeys;
    final allSelected =
        selected.length == all.length && all.every((k) => selected.contains(k));

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: 400, minWidth: 240),
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(vertical: 6),
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
            Divider(height: 1, color: context.colors.border),
            for (final s in ['todo', 'doing', 'done', 'blocked'])
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
  _FilterMenuActionRow({
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
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(
              selected ? Icons.check_box : Icons.check_box_outline_blank,
              size: 18,
              color: selected ? context.colors.accent : context.colors.dim,
            ),
            SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: selected ? context.colors.text : context.colors.muted,
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
  _ProjectFilterRow({
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
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Row(
          children: [
            SizedBox(width: indent ? 22 : 0),
            Icon(
              selected ? Icons.check_box : Icons.check_box_outline_blank,
              size: 18,
              color: selected ? context.colors.accent : context.colors.dim,
            ),
            SizedBox(width: 10),
            if (!indent) ...[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Color(project.color),
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 8),
            ] else ...[
              Icon(
                Icons.subdirectory_arrow_right,
                size: 14,
                color: context.colors.dim,
              ),
              SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                project.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: indent ? context.colors.muted : context.colors.text,
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
