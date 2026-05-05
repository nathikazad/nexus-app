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
                      icon: Icons.add,
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
        ],
      ),
    );
  }
}

class _IconSquareButton extends StatelessWidget {
  const _IconSquareButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
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
