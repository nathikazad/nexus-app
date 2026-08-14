part of 'desktop_workspace.dart';

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
