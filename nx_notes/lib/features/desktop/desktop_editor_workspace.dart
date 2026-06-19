part of 'desktop_shell.dart';

class _DesktopEditorWorkspace extends ConsumerWidget {
  const _DesktopEditorWorkspace({required this.workspace});

  final DesktopWorkspaceState workspace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeDocumentId = workspace.activeDocumentId;
    final activeTab = workspace.activeTab;
    return Column(
      children: <Widget>[
        Container(
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.sidebar,
            border: Border(bottom: BorderSide(color: AppColors.line)),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(left: 8, top: 8),
                  scrollDirection: Axis.horizontal,
                  children: <Widget>[
                    for (final tab in workspace.openTabs)
                      _EditorTab(
                        tab: tab,
                        active: tab.documentId == workspace.activeDocumentId,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (workspace.activeContext != null && activeDocumentId != null)
          EditorContextBar(
            resultContext: workspace.activeContext!,
            activeDocumentId: activeDocumentId,
            onBack: () => ref
                .read(desktopWorkspaceProvider.notifier)
                .showOverlay(
                  title: workspace.activeContext!.title,
                  query: workspace.activeContext!.query,
                  resultIds: workspace.activeContext!.resultIds,
                  results: workspace.activeContext!.results,
                ),
            onClear: () => ref
                .read(desktopWorkspaceProvider.notifier)
                .clearActiveContext(),
          ),
        Expanded(
          child: activeDocumentId == null || activeTab == null
              ? const _NoDocumentSelected()
              : _MountedEditorStack(
                  tab: activeTab,
                  canNavigateBack: workspace.canNavigateActiveTabBack,
                ),
        ),
      ],
    );
  }
}

class _MountedEditorStack extends ConsumerWidget {
  const _MountedEditorStack({required this.tab, required this.canNavigateBack});

  final DocumentTabState tab;
  final bool canNavigateBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stack = tab.editorStack;
    final rawActiveIndex = stack.indexOf(tab.documentId);
    final activeIndex = rawActiveIndex < 0 ? 0 : rawActiveIndex;
    return IndexedStack(
      index: activeIndex,
      sizing: StackFit.expand,
      children: <Widget>[
        for (final documentId in stack)
          _MountedEditorSession(
            key: ValueKey<int>(documentId),
            documentId: documentId,
            active: documentId == tab.documentId,
            canNavigateBack: canNavigateBack,
          ),
      ],
    );
  }
}

class _MountedEditorSession extends ConsumerWidget {
  const _MountedEditorSession({
    required this.documentId,
    required this.active,
    required this.canNavigateBack,
    super.key,
  });

  final int documentId;
  final bool active;
  final bool canNavigateBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TickerMode(
      enabled: active,
      child: IgnorePointer(
        ignoring: !active,
        child: DocumentEditorView(
          documentId: documentId,
          active: active,
          onOpenDocumentLink: (linkedDocumentId) => ref
              .read(desktopWorkspaceProvider.notifier)
              .openDocumentInActiveTab(linkedDocumentId),
          canNavigateBack: active && canNavigateBack,
          onNavigateBack: active
              ? () => ref
                    .read(desktopWorkspaceProvider.notifier)
                    .backInActiveTab()
              : null,
        ),
      ),
    );
  }
}

class _NoDocumentSelected extends ConsumerWidget {
  const _NoDocumentSelected();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentDocumentsProvider);
    return recent.when(
      data: (rows) {
        if (rows.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref
                .read(desktopWorkspaceProvider.notifier)
                .openDocument(rows.first.id);
          });
          return const Center(child: CircularProgressIndicator());
        }
        return Center(
          child: Text(
            'Create an document from the sidebar.',
            style: TextStyle(color: AppColors.muted),
          ),
        );
      },
      error: (error, stackTrace) => Center(child: Text('$error')),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }
}

class _EditorTab extends ConsumerWidget {
  const _EditorTab({required this.tab, required this.active});

  final DocumentTabState tab;
  final bool active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final document = ref.watch(documentByIdProvider(tab.documentId)).value;
    return Material(
      color: active ? AppColors.panel : Colors.transparent,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
      child: InkWell(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
        onTap: () => ref
            .read(desktopWorkspaceProvider.notifier)
            .openDocument(tab.documentId),
        child: Container(
          width: 178,
          padding: const EdgeInsets.fromLTRB(12, 0, 7, 0),
          decoration: BoxDecoration(
            border: active
                ? Border(
                    top: BorderSide(color: AppColors.line),
                    left: BorderSide(color: AppColors.line),
                    right: BorderSide(color: AppColors.line),
                  )
                : null,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
          ),
          child: Row(
            children: <Widget>[
              if (tab.dirty) ...<Widget>[
                Icon(Icons.circle, size: 7, color: AppColors.amber),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  document?.title ?? 'Document ${tab.documentId}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: active ? AppColors.text : AppColors.muted,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 24,
                  height: 24,
                ),
                onPressed: () => ref
                    .read(desktopWorkspaceProvider.notifier)
                    .closeTab(tab.documentId),
                icon: Icon(Icons.close, size: 15, color: AppColors.faint),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
