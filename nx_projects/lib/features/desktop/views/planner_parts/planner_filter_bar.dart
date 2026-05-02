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
