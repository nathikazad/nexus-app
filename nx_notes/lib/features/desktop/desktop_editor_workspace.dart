part of 'desktop_shell.dart';

class _DesktopEditorWorkspace extends ConsumerWidget {
  const _DesktopEditorWorkspace({required this.workspace});

  final DesktopWorkspaceState workspace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeEssayId = workspace.activeEssayId;
    final activeTab = workspace.activeTab;
    return Column(
      children: <Widget>[
        Container(
          height: 40,
          decoration: const BoxDecoration(
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
                        active: tab.essayId == workspace.activeEssayId,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (workspace.activeContext != null && activeEssayId != null)
          EditorContextBar(
            resultContext: workspace.activeContext!,
            activeEssayId: activeEssayId,
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
          child: activeEssayId == null || activeTab == null
              ? const _NoEssaySelected()
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

  final EssayTabState tab;
  final bool canNavigateBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stack = tab.editorStack;
    final rawActiveIndex = stack.indexOf(tab.essayId);
    final activeIndex = rawActiveIndex < 0 ? 0 : rawActiveIndex;
    return IndexedStack(
      index: activeIndex,
      sizing: StackFit.expand,
      children: <Widget>[
        for (final essayId in stack)
          _MountedEditorSession(
            key: ValueKey<int>(essayId),
            essayId: essayId,
            active: essayId == tab.essayId,
            canNavigateBack: canNavigateBack,
          ),
      ],
    );
  }
}

class _MountedEditorSession extends ConsumerWidget {
  const _MountedEditorSession({
    required this.essayId,
    required this.active,
    required this.canNavigateBack,
    super.key,
  });

  final int essayId;
  final bool active;
  final bool canNavigateBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TickerMode(
      enabled: active,
      child: IgnorePointer(
        ignoring: !active,
        child: EssayEditorView(
          essayId: essayId,
          active: active,
          onOpenEssayLink: (linkedEssayId) => ref
              .read(desktopWorkspaceProvider.notifier)
              .openEssayInActiveTab(linkedEssayId),
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

class _NoEssaySelected extends ConsumerWidget {
  const _NoEssaySelected();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentEssaysProvider);
    return recent.when(
      data: (rows) {
        if (rows.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref
                .read(desktopWorkspaceProvider.notifier)
                .openEssay(rows.first.id);
          });
          return const Center(child: CircularProgressIndicator());
        }
        return const Center(
          child: Text(
            'Create an essay from the sidebar.',
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

  final EssayTabState tab;
  final bool active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final essay = ref.watch(essayByIdProvider(tab.essayId)).value;
    return Material(
      color: active ? AppColors.panel : Colors.transparent,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
      child: InkWell(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
        onTap: () =>
            ref.read(desktopWorkspaceProvider.notifier).openEssay(tab.essayId),
        child: Container(
          width: 178,
          padding: const EdgeInsets.fromLTRB(12, 0, 7, 0),
          decoration: BoxDecoration(
            border: active
                ? const Border(
                    top: BorderSide(color: AppColors.line),
                    left: BorderSide(color: AppColors.line),
                    right: BorderSide(color: AppColors.line),
                  )
                : null,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
          ),
          child: Row(
            children: <Widget>[
              if (tab.dirty) ...const <Widget>[
                Icon(Icons.circle, size: 7, color: AppColors.amber),
                SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  essay?.title ?? 'Essay ${tab.essayId}',
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
                    .closeTab(tab.essayId),
                icon: const Icon(Icons.close, size: 15, color: AppColors.faint),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
