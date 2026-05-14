part of 'desktop_shell.dart';

class _DesktopSidebar extends ConsumerStatefulWidget {
  const _DesktopSidebar();

  @override
  ConsumerState<_DesktopSidebar> createState() => _DesktopSidebarState();
}

class _DesktopSidebarState extends ConsumerState<_DesktopSidebar> {
  @override
  Widget build(BuildContext context) {
    final workspace = ref.watch(desktopWorkspaceProvider);
    final recent = ref.watch(recentEssaysProvider);
    final pinned = ref.watch(pinnedEssaysProvider);
    final tagSystems = ref.watch(tagSystemsProvider);
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.sidebar,
        border: Border(right: BorderSide(color: AppColors.line)),
      ),
      child: Column(
        children: <Widget>[
          SizedBox(
            height: 48,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.line)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.text,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'N',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'nx_notes',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    _IconSquareButton(
                      icon: Icons.chevron_left,
                      tooltip: 'Collapse navigator',
                      onPressed: () => ref
                          .read(desktopWorkspaceProvider.notifier)
                          .toggleSidebar(),
                    ),
                    const SizedBox(width: 6),
                    _IconSquareButton(
                      icon: Icons.add,
                      tooltip: 'New essay',
                      onPressed: () async {
                        final essay = await ref
                            .read(essayMutationControllerProvider)
                            .createEssay();
                        ref
                            .read(desktopWorkspaceProvider.notifier)
                            .openEssay(essay.id);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
            child: _SearchField(
              onSubmitted: (value) async {
                final result = await ref
                    .read(essayResultControllerProvider)
                    .search(value);
                ref
                    .read(desktopWorkspaceProvider.notifier)
                    .showOverlay(
                      title: result.title,
                      query: result.query,
                      resultIds: result.resultIds,
                      results: result.results,
                    );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
            child: Row(
              children: <Widget>[
                _SidebarTabButton(
                  label: 'Essays',
                  active: workspace.sidebarTab == SidebarTab.essays,
                  onTap: () => ref
                      .read(desktopWorkspaceProvider.notifier)
                      .setSidebarTab(SidebarTab.essays),
                ),
                _SidebarTabButton(
                  label: 'Tags',
                  active: workspace.sidebarTab == SidebarTab.tags,
                  onTap: () => ref
                      .read(desktopWorkspaceProvider.notifier)
                      .setSidebarTab(SidebarTab.tags),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: workspace.sidebarTab == SidebarTab.essays
                ? _SidebarEssays(recent: recent, pinned: pinned)
                : _SidebarTags(tagSystems: tagSystems),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: _SidebarFooterButton(
              icon: Icons.logout,
              label: 'Log out',
              onTap: () async {
                await ref.read(authProvider.notifier).logout();
                if (context.mounted) context.go('/login');
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CollapsedSidebar extends ConsumerWidget {
  const _CollapsedSidebar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.sidebar,
        border: Border(right: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            const SizedBox(height: 6),
            _CollapsedSidebarButton(
              icon: Icons.chevron_right,
              tooltip: 'Expand navigator',
              onTap: () =>
                  ref.read(desktopWorkspaceProvider.notifier).toggleSidebar(),
            ),
            const SizedBox(height: 8),
            const RotatedBox(
              quarterTurns: 1,
              child: Text(
                'nx_notes',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.faint,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CollapsedSidebarButton extends StatelessWidget {
  const _CollapsedSidebarButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      preferBelow: false,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            child: Icon(icon, size: 18, color: AppColors.faint),
          ),
        ),
      ),
    );
  }
}

class _SidebarFooterButton extends StatelessWidget {
  const _SidebarFooterButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 17, color: AppColors.faint),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconSquareButton extends StatelessWidget {
  const _IconSquareButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: AppColors.panel,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onPressed,
        child: Container(
          width: 26,
          height: 24,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(icon, size: 16, color: AppColors.muted),
        ),
      ),
    );
    if (tooltip == null) {
      return button;
    }
    return Tooltip(message: tooltip!, preferBelow: false, child: button);
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.onSubmitted});

  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      style: const TextStyle(fontSize: 13),
      decoration: const InputDecoration(
        hintText: 'Search essays...',
        prefixIcon: Icon(Icons.search, size: 18, color: AppColors.faint),
        prefixIconConstraints: BoxConstraints(minWidth: 34),
      ),
      onSubmitted: onSubmitted,
    );
  }
}

class _SidebarTabButton extends StatelessWidget {
  const _SidebarTabButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: active
            ? const BoxDecoration(
                color: AppColors.panel,
                border: Border(
                  top: BorderSide(color: AppColors.line),
                  left: BorderSide(color: AppColors.line),
                  right: BorderSide(color: AppColors.line),
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
              )
            : null,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: active ? AppColors.text : AppColors.muted,
          ),
        ),
      ),
    );
  }
}

class _SidebarEssays extends ConsumerWidget {
  const _SidebarEssays({required this.recent, required this.pinned});

  final AsyncValue<List<Essay>> recent;
  final AsyncValue<List<Essay>> pinned;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: <Widget>[
        _SidebarSection(
          title: 'Pinned',
          onTitleTap: () async {
            final result = await ref
                .read(essayResultControllerProvider)
                .pinned();
            ref
                .read(desktopWorkspaceProvider.notifier)
                .showOverlay(
                  title: result.title,
                  query: result.query,
                  resultIds: result.resultIds,
                  results: result.results,
                );
          },
          rows: pinned.value?.take(5).toList() ?? const <Essay>[],
          pinned: true,
        ),
        const SizedBox(height: 22),
        _SidebarSection(
          title: 'Recent',
          onTitleTap: () async {
            final result = await ref
                .read(essayResultControllerProvider)
                .recent();
            ref
                .read(desktopWorkspaceProvider.notifier)
                .showOverlay(
                  title: result.title,
                  query: result.query,
                  resultIds: result.resultIds,
                  results: result.results,
                );
          },
          rows: recent.value?.take(5).toList() ?? const <Essay>[],
        ),
      ],
    );
  }
}

class _SidebarSection extends ConsumerWidget {
  const _SidebarSection({
    required this.title,
    required this.rows,
    required this.onTitleTap,
    this.pinned = false,
  });

  final String title;
  final List<Essay> rows;
  final VoidCallback onTitleTap;
  final bool pinned;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        GestureDetector(
          onTap: onTitleTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
            child: Text(
              title.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.faint,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        for (final essay in rows)
          _SidebarEssayLink(
            essay: essay,
            pinned: pinned,
            onTap: () =>
                ref.read(desktopWorkspaceProvider.notifier).openEssay(essay.id),
          ),
      ],
    );
  }
}

class _SidebarEssayLink extends StatelessWidget {
  const _SidebarEssayLink({
    required this.essay,
    required this.onTap,
    this.pinned = false,
  });

  final Essay essay;
  final VoidCallback onTap;
  final bool pinned;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          child: Row(
            children: <Widget>[
              if (pinned)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(
                    Icons.push_pin_outlined,
                    size: 15,
                    color: AppColors.faint,
                  ),
                ),
              Expanded(
                child: Text(
                  essay.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarTags extends ConsumerWidget {
  const _SidebarTags({required this.tagSystems});

  final AsyncValue<List<TagSystem>> tagSystems;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final systems = tagSystems.value ?? const <TagSystem>[];
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 24),
      children: <Widget>[
        for (final system in systems) ...<Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
            child: Text(
              system.name.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.faint,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          for (final node in system.nodes) ..._tagRows(ref, system.name, node),
          const SizedBox(height: 22),
        ],
      ],
    );
  }

  List<Widget> _tagRows(
    WidgetRef ref,
    String system,
    TagNode node, [
    int depth = 0,
  ]) {
    return <Widget>[
      Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () async {
            final result = await ref
                .read(essayResultControllerProvider)
                .tag(
                  system: system,
                  node: node.name,
                  includeDescendants: depth == 0,
                );
            ref
                .read(desktopWorkspaceProvider.notifier)
                .showOverlay(
                  title: result.title,
                  query: result.query,
                  resultIds: result.resultIds,
                  results: result.results,
                );
          },
          child: Padding(
            padding: EdgeInsets.fromLTRB(8 + depth * 14.0, 7, 8, 7),
            child: Row(
              children: <Widget>[
                if (depth == 0 && node.children.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      size: 16,
                      color: AppColors.faint,
                    ),
                  ),
                Expanded(
                  child: Text(
                    node.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  '${node.count}',
                  style: const TextStyle(fontSize: 12, color: AppColors.faint),
                ),
              ],
            ),
          ),
        ),
      ),
      for (final child in node.children)
        ..._tagRows(ref, system, child, depth + 1),
    ];
  }
}
