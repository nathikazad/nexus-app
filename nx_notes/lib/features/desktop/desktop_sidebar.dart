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
    final recent = ref.watch(recentDocumentsProvider);
    final pinned = ref.watch(pinnedDocumentsProvider);
    final books = ref.watch(booksProvider);
    final tagSystems = ref.watch(tagSystemsProvider);
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
                    const _NewDocumentMenuButton(),
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
                    .read(documentResultControllerProvider)
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
                  label: 'Docs',
                  active: workspace.sidebarTab == SidebarTab.documents,
                  onTap: () => ref
                      .read(desktopWorkspaceProvider.notifier)
                      .setSidebarTab(SidebarTab.documents),
                ),
                _SidebarTabButton(
                  label: 'Books',
                  active: workspace.sidebarTab == SidebarTab.books,
                  onTap: () => ref
                      .read(desktopWorkspaceProvider.notifier)
                      .setSidebarTab(SidebarTab.books),
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
            child: switch (workspace.sidebarTab) {
              SidebarTab.documents => _SidebarDocuments(
                recent: recent,
                pinned: pinned,
              ),
              SidebarTab.books => _SidebarBooks(books: books),
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
                      await ref.read(authProvider.notifier).logout();
                      if (context.mounted) context.go('/login');
                    },
                  ),
                ),
                const SizedBox(width: 6),
                const AppThemeToggleButton(),
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
  final _buttonKey = GlobalKey();
  OverlayEntry? _entry;
  var _busy = false;

  @override
  void dispose() {
    _hideMenu();
    super.dispose();
  }

  void _toggleMenu() {
    if (_entry == null) {
      _showMenu();
    } else {
      _hideMenu();
    }
  }

  void _showMenu() {
    final buttonBox =
        _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    final overlay = Overlay.of(context, rootOverlay: true);
    if (buttonBox == null) return;

    final buttonOffset = buttonBox.localToGlobal(Offset.zero);
    final screenSize = MediaQuery.sizeOf(context);
    const width = 164.0;
    const margin = 8.0;
    final left = buttonOffset.dx.clamp(
      margin,
      screenSize.width - width - margin,
    );
    final top = (buttonOffset.dy + buttonBox.size.height + 7).clamp(
      margin,
      screenSize.height - 94,
    );

    _entry = OverlayEntry(
      builder: (_) {
        return Stack(
          children: <Widget>[
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _hideMenu,
              ),
            ),
            Positioned(
              left: left,
              top: top,
              width: width,
              child: _NewDocumentMenuSurface(
                busy: _busy,
                onCreateDocument: () =>
                    unawaited(_createDocument(DocumentKind.document)),
                onCreateBook: () =>
                    unawaited(_createDocument(DocumentKind.book)),
              ),
            ),
          ],
        );
      },
    );
    overlay.insert(_entry!);
  }

  void _hideMenu() {
    _entry?.remove();
    _entry = null;
  }

  Future<void> _createDocument(DocumentKind kind) async {
    if (_busy) return;
    setState(() => _busy = true);
    _entry?.markNeedsBuild();
    try {
      _hideMenu();
      final document = await ref
          .read(documentMutationControllerProvider)
          .createDocument(kind: kind);
      ref.read(desktopWorkspaceProvider.notifier).openDocument(document.id);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'New',
      preferBelow: false,
      child: Material(
        key: _buttonKey,
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: _busy ? null : _toggleMenu,
          child: Container(
            width: 26,
            height: 24,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.line),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(Icons.add, size: 16, color: AppColors.muted),
          ),
        ),
      ),
    );
  }
}

class _NewDocumentMenuSurface extends StatelessWidget {
  const _NewDocumentMenuSurface({
    required this.busy,
    required this.onCreateDocument,
    required this.onCreateBook,
  });

  final bool busy;
  final VoidCallback onCreateDocument;
  final VoidCallback onCreateBook;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.panel,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(8),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x1a000000),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _NewDocumentMenuRow(
                icon: Icons.description_outlined,
                label: 'Document',
                enabled: !busy,
                onTap: onCreateDocument,
              ),
              _NewDocumentMenuRow(
                icon: Icons.menu_book_outlined,
                label: 'Book',
                enabled: !busy,
                onTap: onCreateBook,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewDocumentMenuRow extends StatelessWidget {
  const _NewDocumentMenuRow({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: SizedBox(
            height: 32,
            child: Row(
              children: <Widget>[
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.subtle,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Icon(icon, size: 15, color: AppColors.muted),
                ),
                const SizedBox(width: 9),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: enabled ? AppColors.text : AppColors.faint,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
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
      decoration: InputDecoration(
        hintText: 'Search documents...',
        prefixIcon: Icon(Icons.search, size: 18, color: AppColors.faint),
        prefixIconConstraints: const BoxConstraints(minWidth: 34),
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

class _SidebarDocuments extends ConsumerWidget {
  const _SidebarDocuments({required this.recent, required this.pinned});

  final AsyncValue<List<NxDocument>> recent;
  final AsyncValue<List<NxDocument>> pinned;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: <Widget>[
        _SidebarSection(
          title: 'Pinned',
          onTitleTap: () async {
            final result = await ref
                .read(documentResultControllerProvider)
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
          rows: pinned.value?.take(5).toList() ?? const <NxDocument>[],
          pinned: true,
        ),
        const SizedBox(height: 22),
        _SidebarSection(
          title: 'Recent',
          onTitleTap: () async {
            final result = await ref
                .read(documentResultControllerProvider)
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
          rows: recent.value?.take(5).toList() ?? const <NxDocument>[],
        ),
      ],
    );
  }
}

class _SidebarBooks extends ConsumerWidget {
  const _SidebarBooks({required this.books});

  final AsyncValue<List<NxDocument>> books;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: <Widget>[
        _SidebarSection(
          title: 'Books',
          onTitleTap: () {},
          rows: books.value ?? const <NxDocument>[],
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
  final List<NxDocument> rows;
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
              style: TextStyle(
                fontSize: 11,
                color: AppColors.faint,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        for (final document in rows)
          _SidebarDocumentLink(
            document: document,
            pinned: pinned,
            onTap: () => ref
                .read(desktopWorkspaceProvider.notifier)
                .openDocument(document.id),
          ),
      ],
    );
  }
}

class _SidebarDocumentLink extends StatelessWidget {
  const _SidebarDocumentLink({
    required this.document,
    required this.onTap,
    this.pinned = false,
  });

  final NxDocument document;
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
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(
                    Icons.push_pin_outlined,
                    size: 15,
                    color: AppColors.faint,
                  ),
                ),
              Expanded(
                child: Text(
                  document.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
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
              style: TextStyle(
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
                .read(documentResultControllerProvider)
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
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
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
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  '${node.count}',
                  style: TextStyle(fontSize: 12, color: AppColors.faint),
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
