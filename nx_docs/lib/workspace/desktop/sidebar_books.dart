part of 'desktop_workspace.dart';

class _SidebarBooks extends ConsumerStatefulWidget {
  const _SidebarBooks({
    required this.books,
    required this.tagSystems,
    required this.liveQuery,
  });

  final AsyncValue<List<NxDocument>> books;
  final AsyncValue<List<TagSystem>> tagSystems;
  final String liveQuery;

  @override
  ConsumerState<_SidebarBooks> createState() => _SidebarBooksState();
}

class _SidebarBooksState extends ConsumerState<_SidebarBooks> {
  final Set<String> _selectedTopics = <String>{};
  BookCollectionView _collection = BookCollectionView.toRead;

  @override
  Widget build(BuildContext context) {
    final rows = _filteredRows(widget.books.value ?? const <NxDocument>[]);
    final reading = booksForReadingState(rows, 'reading');
    final collection = booksForReadingState(rows, _collection.value);
    final topics = _topicOptions(
      widget.tagSystems.value ?? const <TagSystem>[],
      widget.books.value ?? const <NxDocument>[],
    );
    return ListView(
      padding: const EdgeInsets.all(12),
      children: <Widget>[
        _SidebarBooksHeader(
          hasFilters: _selectedTopics.isNotEmpty,
          searchActive: widget.liveQuery.isNotEmpty,
          topics: topics,
          selectedTopics: _selectedTopics,
          onToggleTopic: (topic) => setState(() {
            _toggle(_selectedTopics, topic);
          }),
          onClear: () => setState(() {
            _selectedTopics.clear();
          }),
        ),
        BookShelfSectionHeader(
          title: 'Currently Reading',
          count: reading.length,
        ),
        const SizedBox(height: 5),
        for (final document in reading)
          _SidebarDocumentLink(
            document: document,
            onTap: () => ref
                .read(desktopWorkspaceProvider.notifier)
                .openDocument(document.id),
          ),
        if (reading.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(8, 8, 8, 4),
            child: _SidebarMutedText('No books in progress'),
          ),
        const SizedBox(height: 18),
        BookShelfSectionHeader(
          title: '',
          count: collection.length,
          trailing: BookCollectionSwitch(
            value: _collection,
            onChanged: (value) => setState(() => _collection = value),
          ),
        ),
        const SizedBox(height: 5),
        for (final document in collection)
          _SidebarDocumentLink(
            document: document,
            onTap: () => ref
                .read(desktopWorkspaceProvider.notifier)
                .openDocument(document.id),
          ),
        if (collection.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Text(
              _collection == BookCollectionView.toRead
                  ? 'No books waiting'
                  : 'No finished books',
              style: TextStyle(fontSize: 12, color: AppColors.faint),
            ),
          ),
      ],
    );
  }

  List<NxDocument> _filteredRows(List<NxDocument> rows) {
    final query = widget.liveQuery.trim().toLowerCase();
    return [
      for (final row in rows)
        if (query.isEmpty ? _matchesFilters(row) : _matchesSearch(row, query))
          row,
    ]..sort(_compareBooks);
  }

  bool _matchesSearch(NxDocument document, String query) {
    return [
      document.title,
      document.excerpt,
      document.status,
      document.readingState,
      ...document.tagsBySystem.values.expand((tags) => tags),
    ].join(' ').toLowerCase().contains(query);
  }

  bool _matchesFilters(NxDocument document) {
    if (_selectedTopics.isNotEmpty &&
        !document.topics.any(_selectedTopics.contains)) {
      return false;
    }
    return true;
  }

  int _compareBooks(NxDocument a, NxDocument b) {
    final rank = (a.bookRank ?? 1 << 30).compareTo(b.bookRank ?? 1 << 30);
    if (rank != 0) return rank;
    return a.title.toLowerCase().compareTo(b.title.toLowerCase());
  }

  List<String> _topicOptions(List<TagSystem> systems, List<NxDocument> books) {
    final topicSystem = systems.where((system) => system.name == 'Topic');
    final options = <String>{
      for (final system in topicSystem)
        for (final node in system.nodes) ..._flattenTagNodeNames(node),
      for (final book in books) ...book.topics,
    }.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return options;
  }

  void _toggle(Set<String> set, String value) {
    if (!set.add(value)) {
      set.remove(value);
    }
  }
}

class _SidebarBooksHeader extends StatelessWidget {
  const _SidebarBooksHeader({
    required this.hasFilters,
    required this.searchActive,
    required this.topics,
    required this.selectedTopics,
    required this.onToggleTopic,
    required this.onClear,
  });

  final bool hasFilters;
  final bool searchActive;
  final List<String> topics;
  final Set<String> selectedTopics;
  final ValueChanged<String> onToggleTopic;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'BOOKS',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.faint,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (searchActive && hasFilters)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      'Filters paused while searching',
                      style: TextStyle(fontSize: 10, color: AppColors.faint),
                    ),
                  ),
              ],
            ),
          ),
          PopupMenuButton<_BookFilterAction>(
            tooltip: 'Filter books',
            color: AppColors.panel,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            onSelected: (action) {
              switch (action.kind) {
                case _BookFilterKind.topic:
                  onToggleTopic(action.value);
                case _BookFilterKind.clear:
                  onClear();
              }
            },
            itemBuilder: (context) => <PopupMenuEntry<_BookFilterAction>>[
              PopupMenuItem<_BookFilterAction>(
                enabled: false,
                height: 28,
                child: Text(
                  'Topic',
                  style: TextStyle(fontSize: 11, color: AppColors.faint),
                ),
              ),
              for (final topic in topics)
                CheckedPopupMenuItem<_BookFilterAction>(
                  value: _BookFilterAction(_BookFilterKind.topic, topic),
                  checked: selectedTopics.contains(topic),
                  height: 34,
                  child: Text(topic, style: const TextStyle(fontSize: 13)),
                ),
              if (hasFilters) ...<PopupMenuEntry<_BookFilterAction>>[
                const PopupMenuDivider(height: 8),
                const PopupMenuItem<_BookFilterAction>(
                  value: _BookFilterAction(_BookFilterKind.clear, ''),
                  height: 34,
                  child: Text('Clear filters', style: TextStyle(fontSize: 13)),
                ),
              ],
            ],
            child: Container(
              width: 24,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: hasFilters ? AppColors.subtle : AppColors.panel,
                border: Border.all(color: AppColors.line),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(
                Icons.filter_list,
                size: 14,
                color: hasFilters ? AppColors.text : AppColors.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _BookFilterKind { topic, clear }

class _BookFilterAction {
  const _BookFilterAction(this.kind, this.value);

  final _BookFilterKind kind;
  final String value;
}

List<String> _flattenTagNodeNames(TagNode node) {
  return <String>[
    node.name,
    for (final child in node.children) ..._flattenTagNodeNames(child),
  ];
}
