part of 'desktop_workspace.dart';

class _DesktopSidebar extends ConsumerStatefulWidget {
  const _DesktopSidebar();

  @override
  ConsumerState<_DesktopSidebar> createState() => _DesktopSidebarState();
}

class _DesktopSidebarState extends ConsumerState<_DesktopSidebar> {
  Timer? _searchDebounce;
  final _searchController = TextEditingController();
  String _searchText = '';
  String _liveSearchText = '';

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() => _searchText = value);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      setState(() => _liveSearchText = _searchText.trim());
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    setState(() {
      _searchText = '';
      _liveSearchText = '';
    });
  }

  Future<void> _submitSearch(String value) async {
    _searchDebounce?.cancel();
    final query = value.trim();
    setState(() {
      _searchText = value;
      _liveSearchText = query;
    });
    final result = await ref
        .read(documentResultControllerProvider)
        .search(query);
    if (!mounted) return;
    ref
        .read(desktopWorkspaceProvider.notifier)
        .showOverlay(
          title: result.title,
          query: result.query,
          resultIds: result.resultIds,
          results: result.results,
        );
  }

  @override
  Widget build(BuildContext context) {
    final workspace = ref.watch(desktopWorkspaceProvider);
    final recent = workspace.sidebarTab == SidebarTab.documents
        ? ref.watch(offlineRecentDocumentsProvider)
        : const AsyncData<List<NxDocument>>([]);
    final pinned = workspace.sidebarTab == SidebarTab.documents
        ? ref.watch(offlinePinnedDocumentsProvider)
        : const AsyncData<List<NxDocument>>([]);
    final tagSystems = workspace.sidebarTab == SidebarTab.tags
        ? ref.watch(offlineTagSystemsProvider)
        : const AsyncData<List<TagSystem>>([]);
    final liveQuery = _liveSearchText;
    final liveDocuments =
        liveQuery.isNotEmpty && workspace.sidebarTab == SidebarTab.documents
        ? ref.watch(offlineDocumentSearchProvider(liveQuery))
        : const AsyncData<List<NxDocument>>(<NxDocument>[]);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.sidebar,
        border: Border(right: BorderSide(color: AppColors.line)),
      ),
      child: Column(
        children: <Widget>[
          SizedBox(
            height: 48,
            child: DecoratedBox(
              decoration: BoxDecoration(
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
                        color: AppColors.floating,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'N',
                        style: TextStyle(
                          color: AppColors.onFloating,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Nx Docs',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    _IconSquareButton(
                      icon: Icons.chevron_left,
                      tooltip: 'Collapse navigator',
                      onPressed: () => ref
                          .read(desktopWorkspaceProvider.notifier)
                          .toggleSidebar(),
                    ),
                    const SizedBox(width: 6),
                    const _NewDocumentMenuButton(),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
            child: _SearchField(
              controller: _searchController,
              hasText: _searchText.isNotEmpty,
              onChanged: _onSearchChanged,
              onClear: _clearSearch,
              onSubmitted: (value) => unawaited(_submitSearch(value)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: _SidebarTabButton(
                    label: 'Docs',
                    active: workspace.sidebarTab == SidebarTab.documents,
                    onTap: () => ref
                        .read(desktopWorkspaceProvider.notifier)
                        .setSidebarTab(SidebarTab.documents),
                  ),
                ),
                Expanded(
                  child: _SidebarTabButton(
                    label: 'Tags',
                    active: workspace.sidebarTab == SidebarTab.tags,
                    onTap: () => ref
                        .read(desktopWorkspaceProvider.notifier)
                        .setSidebarTab(SidebarTab.tags),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: switch (workspace.sidebarTab) {
              SidebarTab.documents => _SidebarDocuments(
                recent: recent,
                pinned: pinned,
                liveQuery: liveQuery,
                liveResults: liveDocuments,
              ),
              SidebarTab.tags => _SidebarTags(tagSystems: tagSystems),
            },
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: _SidebarFooterButton(
                    icon: Icons.logout,
                    label: 'Log out',
                    onTap: () async {
                      await ref.read(accountLogoutProvider)();
                      if (context.mounted) context.go('/login');
                    },
                  ),
                ),
                const SizedBox(width: 6),
                const DocsSettingsButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NewDocumentMenuButton extends ConsumerStatefulWidget {
  const _NewDocumentMenuButton();

  @override
  ConsumerState<_NewDocumentMenuButton> createState() =>
      _NewDocumentMenuButtonState();
}

class _NewDocumentMenuButtonState
    extends ConsumerState<_NewDocumentMenuButton> {
  bool _busy = false;

  Future<void> _createDocument() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final document = await ref
          .read(documentMutationControllerProvider)
          .createDocument();
      if (!mounted) return;
      ref.read(desktopWorkspaceProvider.notifier).openDocument(document.id);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not create the document. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => _IconSquareButton(
    icon: Icons.add,
    tooltip: 'New document',
    onPressed: _busy ? null : () => unawaited(_createDocument()),
  );
}

class _CollapsedSidebar extends ConsumerWidget {
  const _CollapsedSidebar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DecoratedBox(
      decoration: BoxDecoration(
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
            RotatedBox(
              quarterTurns: 1,
              child: Text(
                'Nx Docs',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.faint,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ),
            const Spacer(),
            const DocsSettingsButton(),
            const SizedBox(height: 12),
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
                style: TextStyle(
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
  final VoidCallback? onPressed;
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
  const _SearchField({
    required this.controller,
    required this.hasText,
    required this.onChanged,
    required this.onClear,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final bool hasText;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        hintText: 'Search documents...',
        prefixIcon: Icon(Icons.search, size: 18, color: AppColors.faint),
        prefixIconConstraints: const BoxConstraints(minWidth: 34),
        suffixIcon: hasText
            ? IconButton(
                tooltip: 'Clear search',
                icon: Icon(Icons.close, size: 16, color: AppColors.faint),
                splashRadius: 16,
                onPressed: onClear,
              )
            : null,
        suffixIconConstraints: const BoxConstraints(
          minWidth: 34,
          minHeight: 32,
        ),
      ),
      onChanged: onChanged,
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
            ? BoxDecoration(
                color: AppColors.panel,
                border: Border(
                  top: BorderSide(color: AppColors.line),
                  left: BorderSide(color: AppColors.line),
                  right: BorderSide(color: AppColors.line),
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
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
