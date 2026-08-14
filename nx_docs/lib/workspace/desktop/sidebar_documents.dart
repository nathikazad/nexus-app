part of 'desktop_workspace.dart';

class _SidebarDocuments extends ConsumerWidget {
  const _SidebarDocuments({
    required this.recent,
    required this.pinned,
    required this.liveQuery,
    required this.liveResults,
  });

  final AsyncValue<List<NxDocument>> recent;
  final AsyncValue<List<NxDocument>> pinned;
  final String liveQuery;
  final AsyncValue<List<NxDocument>> liveResults;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (liveQuery.isNotEmpty) {
      final rows = liveResults.value ?? const <NxDocument>[];
      return ListView(
        padding: const EdgeInsets.all(12),
        children: <Widget>[
          _SidebarLiveSearchHeader(count: rows.length),
          for (final document in rows)
            _SidebarDocumentLink(
              document: document,
              onTap: () => ref
                  .read(desktopWorkspaceProvider.notifier)
                  .openDocument(document.id),
            ),
          if (liveResults.isLoading)
            const Padding(
              padding: EdgeInsets.fromLTRB(8, 10, 8, 0),
              child: _SidebarMutedText('Searching...'),
            )
          else if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(8, 10, 8, 0),
              child: _SidebarMutedText('No documents match'),
            ),
        ],
      );
    }
    final pinnedRows = pinned.value?.take(5).toList() ?? const <NxDocument>[];
    final recentRows = recent.value?.take(15).toList() ?? const <NxDocument>[];
    return ListView(
      padding: const EdgeInsets.all(12),
      children: <Widget>[
        if (pinnedRows.isNotEmpty) ...<Widget>[
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
            rows: pinnedRows,
            pinned: true,
          ),
          const SizedBox(height: 22),
        ],
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
          rows: recentRows,
        ),
      ],
    );
  }
}

class _SidebarLiveSearchHeader extends StatelessWidget {
  const _SidebarLiveSearchHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              'SEARCH',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.faint,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            '$count',
            style: TextStyle(fontSize: 11, color: AppColors.faint),
          ),
        ],
      ),
    );
  }
}

class _SidebarMutedText extends StatelessWidget {
  const _SidebarMutedText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: TextStyle(fontSize: 12, color: AppColors.faint));
  }
}
