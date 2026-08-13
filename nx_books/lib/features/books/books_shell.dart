import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_books/core/theme/app_theme.dart';
import 'package:nx_books/data/providers.dart';
import 'package:nx_books/domain/book/book.dart';
import 'package:url_launcher/url_launcher.dart';

class BooksRootShell extends ConsumerStatefulWidget {
  const BooksRootShell({super.key});

  @override
  ConsumerState<BooksRootShell> createState() => _BooksRootShellState();
}

class _BooksRootShellState extends ConsumerState<BooksRootShell> {
  bool _selectionSyncScheduled = false;

  @override
  Widget build(BuildContext context) {
    final books = ref.watch(booksProvider);
    return books.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        body: _ErrorState(
          message: error.toString(),
          onRetry: () => ref.invalidate(booksProvider),
        ),
      ),
      data: (rows) {
        _syncSelection(rows);
        final query = ref.watch(searchQueryProvider);
        final topicTag = ref.watch(selectedTopicTagProvider);
        final filtered = _filterBooks(rows, query, topicTag);
        final selectedId = ref.watch(selectedBookIdProvider);
        final selected = _bookById(rows, selectedId);
        return Scaffold(
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 900;
                return compact
                    ? _MobileBookshelf(
                        books: filtered,
                        selected: selected,
                        onOpenInNotes: _openInNotes,
                      )
                    : _DesktopBookshelf(
                        books: filtered,
                        selected: selected,
                        onOpenInNotes: _openInNotes,
                      );
              },
            ),
          ),
        );
      },
    );
  }

  void _syncSelection(List<NxBook> books) {
    if (_selectionSyncScheduled) return;
    final selectedId = ref.read(selectedBookIdProvider);
    final valid =
        selectedId != null && books.any((book) => book.id == selectedId);
    if (books.isEmpty && selectedId == null) return;
    if (books.isNotEmpty && valid) return;
    _selectionSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _selectionSyncScheduled = false;
      if (!mounted) return;
      ref
          .read(selectedBookIdProvider.notifier)
          .select(books.isEmpty ? null : _firstBook(books).id);
    });
  }

  NxBook _firstBook(List<NxBook> books) {
    for (final state in BookReadingState.values) {
      final lane = sortedBooksForState(books, state);
      if (lane.isNotEmpty) return lane.first;
    }
    return books.first;
  }

  List<NxBook> _filterBooks(
    List<NxBook> books,
    String query,
    String? topicTag,
  ) {
    final normalized = query.trim().toLowerCase();
    final normalizedTag = topicTag?.trim().toLowerCase();
    return [
      for (final book in books)
        if ((normalizedTag == null ||
                book.tags.any((tag) => tag.toLowerCase() == normalizedTag)) &&
            (normalized.isEmpty ||
                '${book.title} ${book.author} ${book.description} ${book.readingState.label} ${book.tags.join(' ')}'
                    .toLowerCase()
                    .contains(normalized)))
          book,
    ];
  }

  NxBook? _bookById(List<NxBook> books, int? id) {
    if (id == null) return null;
    for (final book in books) {
      if (book.id == id) return book;
    }
    return null;
  }

  Future<void> _openInNotes(NxBook book) async {
    final uri = notesUriForBook(book.id, Uri.base);
    final ok = await launchUrl(uri, webOnlyWindowName: '_self');
    if (ok || !mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Could not open ${uri.toString()}')));
  }
}

class _DesktopBookshelf extends ConsumerWidget {
  const _DesktopBookshelf({
    required this.books,
    required this.selected,
    required this.onOpenInNotes,
  });

  final List<NxBook> books;
  final NxBook? selected;
  final Future<void> Function(NxBook book) onOpenInNotes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collectionState = ref.watch(bookCollectionStateProvider);
    final optimisticOrders = ref.watch(optimisticBookOrdersProvider);
    final reading = booksInLaneOrder(
      books,
      BookReadingState.reading,
      optimisticOrders[BookReadingState.reading]?.bookIds,
    );
    final collection = booksInLaneOrder(
      books,
      collectionState,
      optimisticOrders[collectionState]?.bookIds,
    );
    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              const _MainHeader(),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Expanded(
                        child: _BookSection(
                          key: const ValueKey('lane-reading'),
                          title: 'Currently Reading',
                          subtitle: 'Books currently in motion',
                          state: BookReadingState.reading,
                          books: reading,
                          selectedId: selected?.id,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Expanded(
                        child: _BookSection(
                          key: ValueKey('lane-${collectionState.kgqlValue}'),
                          title: 'Library',
                          subtitle: collectionState == BookReadingState.toRead
                              ? 'Books waiting to be read'
                              : 'Finished books',
                          state: collectionState,
                          books: collection,
                          selectedId: selected?.id,
                          trailing: _CollectionSwitch(
                            state: collectionState,
                            onChanged: (state) => ref
                                .read(bookCollectionStateProvider.notifier)
                                .set(state),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        SizedBox(
          width: 316,
          child: _BookDetail(book: selected, onOpenInNotes: onOpenInNotes),
        ),
      ],
    );
  }
}

class _MobileBookshelf extends ConsumerStatefulWidget {
  const _MobileBookshelf({
    required this.books,
    required this.selected,
    required this.onOpenInNotes,
  });

  final List<NxBook> books;
  final NxBook? selected;
  final Future<void> Function(NxBook book) onOpenInNotes;

  @override
  ConsumerState<_MobileBookshelf> createState() => _MobileBookshelfState();
}

class _MobileBookshelfState extends ConsumerState<_MobileBookshelf> {
  static const _autoScrollExtent = 120.0;
  static const _maximumAutoScrollSpeed = 900.0;

  final _scrollController = ScrollController();
  final _scrollViewportKey = GlobalKey();
  Timer? _autoScrollTimer;
  double _autoScrollVelocity = 0;

  @override
  void dispose() {
    _stopAutoScroll();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final collectionState = ref.watch(bookCollectionStateProvider);
    final optimisticOrders = ref.watch(optimisticBookOrdersProvider);
    final reading = booksInLaneOrder(
      widget.books,
      BookReadingState.reading,
      optimisticOrders[BookReadingState.reading]?.bookIds,
    );
    final collection = booksInLaneOrder(
      widget.books,
      collectionState,
      optimisticOrders[collectionState]?.bookIds,
    );
    return Column(
      children: [
        _MobileTopBar(totalCount: widget.books.length),
        Expanded(
          child: KeyedSubtree(
            key: _scrollViewportKey,
            child: ListView(
              key: const ValueKey('mobile-books-sections'),
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 20),
              children: [
                _SectionHeader(
                  title: 'Currently Reading',
                  subtitle: 'Books currently in motion',
                  state: BookReadingState.reading,
                  count: reading.length,
                ),
                const SizedBox(height: 10),
                for (final book in reading)
                  _ReorderableBookCard(
                    key: ValueKey('book-card-${book.id}'),
                    book: book,
                    selected: widget.selected?.id == book.id,
                    compact: true,
                    onTap: () => _openBookDetails(
                      context,
                      ref,
                      book,
                      widget.onOpenInNotes,
                    ),
                    onDragStart: _stopAutoScroll,
                    onDragUpdate: _updateAutoScroll,
                    onDragEnd: _stopAutoScroll,
                  ),
                if (reading.isEmpty)
                  const _MobileEmptySection(message: 'No books in progress'),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _SectionHeader(
                        title: 'Library',
                        subtitle: collectionState == BookReadingState.toRead
                            ? 'Books waiting to be read'
                            : 'Finished books',
                        state: collectionState,
                        count: collection.length,
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 184,
                      child: _CollectionSwitch(
                        state: collectionState,
                        onChanged: (state) => ref
                            .read(bookCollectionStateProvider.notifier)
                            .set(state),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                for (final book in collection)
                  _ReorderableBookCard(
                    key: ValueKey('book-card-${book.id}'),
                    book: book,
                    selected: widget.selected?.id == book.id,
                    compact: true,
                    onTap: () => _openBookDetails(
                      context,
                      ref,
                      book,
                      widget.onOpenInNotes,
                    ),
                    onDragStart: _stopAutoScroll,
                    onDragUpdate: _updateAutoScroll,
                    onDragEnd: _stopAutoScroll,
                  ),
                if (collection.isEmpty)
                  _MobileEmptySection(
                    message: collectionState == BookReadingState.toRead
                        ? 'No books waiting'
                        : 'No finished books',
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _updateAutoScroll(Offset globalPosition) {
    final viewport =
        _scrollViewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (viewport == null || !_scrollController.hasClients) {
      _stopAutoScroll();
      return;
    }
    final top = viewport.localToGlobal(Offset.zero).dy;
    final bottom = top + viewport.size.height;
    final distanceFromTop = globalPosition.dy - top;
    final distanceFromBottom = bottom - globalPosition.dy;
    if (distanceFromTop < _autoScrollExtent) {
      final penetration = (1 - distanceFromTop / _autoScrollExtent).clamp(
        0.0,
        1.0,
      );
      _autoScrollVelocity =
          -_maximumAutoScrollSpeed * penetration * penetration;
    } else if (distanceFromBottom < _autoScrollExtent) {
      final penetration = (1 - distanceFromBottom / _autoScrollExtent).clamp(
        0.0,
        1.0,
      );
      _autoScrollVelocity = _maximumAutoScrollSpeed * penetration * penetration;
    } else {
      _stopAutoScroll();
      return;
    }
    _autoScrollTimer ??= Timer.periodic(
      const Duration(milliseconds: 16),
      (_) => _performAutoScroll(),
    );
  }

  void _performAutoScroll() {
    if (!_scrollController.hasClients || _autoScrollVelocity == 0) return;
    final position = _scrollController.position;
    final next = (position.pixels + _autoScrollVelocity * 0.016).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (next == position.pixels) {
      _stopAutoScroll();
      return;
    }
    _scrollController.jumpTo(next);
  }

  void _stopAutoScroll() {
    _autoScrollVelocity = 0;
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
  }

  void _openBookDetails(
    BuildContext context,
    WidgetRef ref,
    NxBook book,
    Future<void> Function(NxBook book) onOpenInNotes,
  ) {
    ref.read(selectedBookIdProvider.notifier).select(book.id);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _MobileBookDetailPage(
          bookId: book.id,
          onOpenInNotes: onOpenInNotes,
        ),
      ),
    );
  }
}

class _MobileTopBar extends ConsumerWidget {
  const _MobileTopBar({required this.totalCount});

  final int totalCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.panel,
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Row(
          children: [
            const _AppMark(),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Nexus Books · $totalCount',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            const _MobileTopicFilterButton(),
            IconButton(
              tooltip: 'Add book',
              onPressed: () => _showCreateBookDialog(context, ref),
              icon: const Icon(Icons.add, size: 19),
            ),
          ],
        ),
      ),
    );
  }
}

class _MainHeader extends ConsumerWidget {
  const _MainHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.bg,
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: SizedBox(
          height: 68,
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bookshelf',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Organize books by state and rank. Rank 0 is first.',
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const _DesktopTopicFilter(),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => ref.invalidate(booksProvider),
                icon: const Icon(Icons.refresh, size: 17),
                label: const Text('Refresh'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => _showCreateBookDialog(context, ref),
                icon: const Icon(Icons.add, size: 17),
                label: const Text('Add Book'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DesktopTopicFilter extends ConsumerWidget {
  const _DesktopTopicFilter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedTopicTagProvider);
    final tags = ref.watch(availableBookTagsProvider);
    return PopupMenuButton<String>(
      key: const ValueKey('desktop-topic-filter'),
      tooltip: 'Filter by topic',
      initialValue: selected ?? '__all__',
      onSelected: (tag) => ref
          .read(selectedTopicTagProvider.notifier)
          .select(tag == '__all__' ? null : tag),
      itemBuilder: (context) => [
        _topicFilterMenuItem('__all__', 'All topics', selected),
        for (final tag in tags) _topicFilterMenuItem(tag, tag, selected),
      ],
      child: Container(
        height: 40,
        constraints: const BoxConstraints(minWidth: 128, maxWidth: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected == null ? AppColors.surface : AppColors.accentSoft,
          border: Border.all(
            color: selected == null ? AppColors.line : const Color(0xffbdd8d3),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.filter_alt_outlined,
              size: 17,
              color: selected == null ? AppColors.muted : AppColors.accent,
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                selected ?? 'All topics',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected == null ? AppColors.text : AppColors.accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 5),
            const Icon(Icons.expand_more, size: 16, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

PopupMenuItem<String> _topicFilterMenuItem(
  String value,
  String label,
  String? selected,
) {
  final active = value == '__all__' ? selected == null : value == selected;
  return PopupMenuItem<String>(
    key: ValueKey('topic-filter-${value == '__all__' ? 'all' : value}'),
    value: value,
    child: Row(
      children: [
        Expanded(child: Text(label)),
        if (active) const Icon(Icons.check, size: 17, color: AppColors.accent),
      ],
    ),
  );
}

class _MobileTopicFilterButton extends ConsumerWidget {
  const _MobileTopicFilterButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedTopicTagProvider);
    return IconButton(
      key: const ValueKey('mobile-topic-filter'),
      tooltip: selected == null ? 'Filter by topic' : 'Topic: $selected',
      onPressed: () => _showMobileTopicFilter(context, ref),
      icon: Badge(
        isLabelVisible: selected != null,
        backgroundColor: AppColors.accent,
        smallSize: 7,
        child: Icon(
          Icons.filter_alt_outlined,
          size: 19,
          color: selected == null ? AppColors.text : AppColors.accent,
        ),
      ),
    );
  }

  Future<void> _showMobileTopicFilter(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final selected = ref.read(selectedTopicTagProvider);
    final tags = ref.read(availableBookTagsProvider);
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.panel,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.72,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Text(
                    'Filter by topic',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      _MobileTopicChoice(
                        label: 'All topics',
                        selected: selected == null,
                        onTap: () => Navigator.of(sheetContext).pop('__all__'),
                      ),
                      for (final tag in tags)
                        _MobileTopicChoice(
                          label: tag,
                          selected:
                              tag.toLowerCase() == selected?.toLowerCase(),
                          onTap: () => Navigator.of(sheetContext).pop(tag),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (choice == null) return;
    ref
        .read(selectedTopicTagProvider.notifier)
        .select(choice == '__all__' ? null : choice);
  }
}

class _MobileTopicChoice extends StatelessWidget {
  const _MobileTopicChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: ValueKey('mobile-topic-choice-$label'),
      minTileHeight: 44,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      selected: selected,
      selectedTileColor: AppColors.accentSoft,
      title: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
      trailing: selected
          ? const Icon(Icons.check, size: 18, color: AppColors.accent)
          : null,
      onTap: onTap,
    );
  }
}

class _BookSection extends StatelessWidget {
  const _BookSection({
    super.key,
    required this.title,
    required this.subtitle,
    required this.state,
    required this.books,
    required this.selectedId,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final BookReadingState state;
  final List<NxBook> books;
  final int? selectedId;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: panelDecoration(color: AppColors.panel),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: _SectionHeader(
                    title: title,
                    subtitle: subtitle,
                    state: state,
                    count: books.length,
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 14),
                  SizedBox(width: 210, child: trailing!),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: books.isEmpty
                ? const _EmptyLane(message: 'No books')
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 720
                          ? 3
                          : constraints.maxWidth >= 440
                          ? 2
                          : 1;
                      return GridView.builder(
                        padding: const EdgeInsets.all(10),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 1,
                          mainAxisExtent: 118,
                        ),
                        itemCount: books.length,
                        itemBuilder: (context, index) {
                          final book = books[index];
                          return _ReorderableBookCard(
                            key: ValueKey('book-card-${book.id}'),
                            book: book,
                            selected: selectedId == book.id,
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.state,
    required this.count,
  });

  final String title;
  final String subtitle;
  final BookReadingState state;
  final int count;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      _StateDot(state: state),
      const SizedBox(width: 8),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ),
      ),
      const SizedBox(width: 8),
      _CountBadge(count: count),
    ],
  );
}

class _CollectionSwitch extends StatelessWidget {
  const _CollectionSwitch({required this.state, required this.onChanged});

  final BookReadingState state;
  final ValueChanged<BookReadingState> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final item in const [BookReadingState.toRead, BookReadingState.read])
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: item == BookReadingState.toRead ? 5 : 0,
            ),
            child: _StateChip(
              key: ValueKey('collection-${item.kgqlValue}'),
              state: item,
              active: item == state,
              onTap: () => onChanged(item),
            ),
          ),
        ),
    ],
  );
}

class _MobileEmptySection extends StatelessWidget {
  const _MobileEmptySection({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
    decoration: panelDecoration(),
    child: Text(
      message,
      textAlign: TextAlign.center,
      style: const TextStyle(color: AppColors.muted, fontSize: 12),
    ),
  );
}

class _BookCard extends ConsumerWidget {
  const _BookCard({
    required this.book,
    required this.selected,
    this.compact = false,
    this.onTap,
  });

  final NxBook book;
  final bool selected;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Material(
        color: selected ? const Color(0xfff4fbf9) : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: selected ? const Color(0xffabcfc8) : AppColors.line,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap:
              onTap ??
              () => ref.read(selectedBookIdProvider.notifier).select(book.id),
          child: Padding(
            padding: EdgeInsets.all(compact ? 11 : 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book.title,
                        maxLines: compact ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (book.author.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          book.author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                            height: 1.25,
                          ),
                        ),
                      ],
                      if (book.tags.isNotEmpty ||
                          book.progressPercent != null) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            if (book.progressPercent != null)
                              _Pill('${book.progressPercent}%'),
                            for (final tag in book.tags.take(6)) _Pill(tag),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (!compact) ...[
                  const SizedBox(width: 6),
                  _LaneMoveButtons(book: book),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReorderableBookCard extends ConsumerStatefulWidget {
  const _ReorderableBookCard({
    super.key,
    required this.book,
    required this.selected,
    this.compact = false,
    this.onTap,
    this.onDragStart,
    this.onDragUpdate,
    this.onDragEnd,
  });

  final NxBook book;
  final bool selected;
  final bool compact;
  final VoidCallback? onTap;
  final VoidCallback? onDragStart;
  final ValueChanged<Offset>? onDragUpdate;
  final VoidCallback? onDragEnd;

  @override
  ConsumerState<_ReorderableBookCard> createState() =>
      _ReorderableBookCardState();
}

class _ReorderableBookCardState extends ConsumerState<_ReorderableBookCard> {
  bool? _placeAfter;
  bool _dragActive = false;

  @override
  void dispose() {
    _finishDrag();
    super.dispose();
  }

  void _startDrag() {
    _dragActive = true;
    widget.onDragStart?.call();
  }

  void _finishDrag() {
    if (!_dragActive) return;
    _dragActive = false;
    widget.onDragEnd?.call();
  }

  bool _isBelowCenter(Offset globalOffset) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return false;
    return box.globalToLocal(globalOffset).dy > box.size.height / 2;
  }

  @override
  Widget build(BuildContext context) {
    final card = _BookCard(
      book: widget.book,
      selected: widget.selected,
      compact: widget.compact,
      onTap: widget.onTap,
    );
    return DragTarget<NxBook>(
      onWillAcceptWithDetails: (details) =>
          details.data.id != widget.book.id &&
          details.data.readingState == widget.book.readingState,
      onMove: (details) {
        final after = _isBelowCenter(details.offset);
        if (_placeAfter != after) setState(() => _placeAfter = after);
      },
      onLeave: (_) => setState(() => _placeAfter = null),
      onAcceptWithDetails: (details) {
        final placeAfter = _isBelowCenter(details.offset);
        setState(() => _placeAfter = null);
        unawaited(
          _saveReorder(
            book: details.data,
            target: widget.book,
            placeAfter: placeAfter,
          ),
        );
      },
      builder: (context, candidates, _) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            LongPressDraggable<NxBook>(
              data: widget.book,
              delay: const Duration(seconds: 2),
              dragAnchorStrategy: pointerDragAnchorStrategy,
              onDragStarted: _startDrag,
              onDragUpdate: (details) =>
                  widget.onDragUpdate?.call(details.globalPosition),
              onDragEnd: (_) => _finishDrag(),
              onDraggableCanceled: (_, _) => _finishDrag(),
              onDragCompleted: _finishDrag,
              feedback: Material(
                elevation: 8,
                color: Colors.transparent,
                child: SizedBox(
                  width: widget.compact ? 330 : 260,
                  child: Opacity(opacity: 0.92, child: card),
                ),
              ),
              childWhenDragging: Opacity(opacity: 0.35, child: card),
              child: card,
            ),
            if (candidates.isNotEmpty && _placeAfter != null)
              Positioned(
                left: 4,
                right: 4,
                top: _placeAfter! ? null : -2,
                bottom: _placeAfter! ? 7 : null,
                child: Container(
                  key: ValueKey(
                    'book-drop-${widget.book.id}-${_placeAfter! ? 'after' : 'before'}',
                  ),
                  height: 3,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _saveReorder({
    required NxBook book,
    required NxBook target,
    required bool placeAfter,
  }) async {
    try {
      await ref
          .read(bookMutationControllerProvider)
          .reorderWithinLane(
            book: book,
            target: target,
            placeAfter: placeAfter,
          );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Could not save the new order. The book was moved back.',
            ),
          ),
        );
    }
  }
}

class _LaneMoveButtons extends ConsumerWidget {
  const _LaneMoveButtons({required this.book});

  final NxBook book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        _SmallIconButton(
          tooltip: 'Move up',
          icon: Icons.keyboard_arrow_up,
          onPressed: () =>
              ref.read(bookMutationControllerProvider).moveWithinLane(book, -1),
        ),
        _SmallIconButton(
          tooltip: 'Move down',
          icon: Icons.keyboard_arrow_down,
          onPressed: () =>
              ref.read(bookMutationControllerProvider).moveWithinLane(book, 1),
        ),
      ],
    );
  }
}

class _BookDetail extends ConsumerWidget {
  const _BookDetail({required this.book, required this.onOpenInNotes});

  final NxBook? book;
  final Future<void> Function(NxBook book) onOpenInNotes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final row = book;
    return DecoratedBox(
      decoration: const BoxDecoration(color: AppColors.panel),
      child: row == null
          ? const Center(
              child: Text(
                'Select a book',
                style: TextStyle(color: AppColors.muted),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Cover(title: row.title),
                      const SizedBox(height: 14),
                      Text(
                        row.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          height: 1.18,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        row.description.isEmpty
                            ? 'No summary yet'
                            : row.description,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 13,
                          height: 1.3,
                        ),
                      ),
                      if (row.author.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          row.author,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const _FieldLabel('State'),
                      _StateSelector(book: row),
                      const SizedBox(height: 18),
                      const _FieldLabel('Rank'),
                      _RankControl(book: row),
                      const SizedBox(height: 18),
                      const _FieldLabel('Chapters'),
                      _ChapterProgressEditor(book: row),
                      const SizedBox(height: 18),
                      const _FieldLabel('Topic'),
                      _TopicTagsEditor(book: row),
                      const SizedBox(height: 18),
                      const _FieldLabel('Metadata'),
                      _MetaRow(label: 'Model', value: 'Book #${row.id}'),
                      if (row.author.isNotEmpty)
                        _MetaRow(label: 'Author', value: row.author),
                      if (row.link.isNotEmpty)
                        _MetaRow(label: 'Link', value: _compactUrl(row.link)),
                      _MetaRow(label: 'State', value: row.readingState.label),
                      _MetaRow(label: 'Rank', value: '${row.rank ?? '-'}'),
                      _MetaRow(
                        label: 'Progress',
                        value: row.progressPercent == null
                            ? '-'
                            : '${row.progressPercent}%',
                      ),
                      _MetaRow(label: 'Updated', value: row.updatedLabel),
                      _MetaRow(label: 'Words', value: '${row.wordCount}'),
                      const SizedBox(height: 10),
                      _BookDetailActions(
                        book: row,
                        onOpenInNotes: onOpenInNotes,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _BookDetailActions extends StatelessWidget {
  const _BookDetailActions({required this.book, required this.onOpenInNotes});

  final NxBook book;
  final Future<void> Function(NxBook book) onOpenInNotes;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: () => onOpenInNotes(book),
          icon: const Icon(Icons.open_in_new, size: 17),
          label: const Text('Open in Notes'),
        ),
        if (book.link.isNotEmpty) ...[
          const SizedBox(height: 8),
          _BookLinkButton(book: book),
        ],
        const SizedBox(height: 8),
        _DeleteBookButton(book: book),
      ],
    );
  }
}

class _BookLinkButton extends StatelessWidget {
  const _BookLinkButton({required this.book});

  final NxBook book;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => _openLink(context),
      icon: const Icon(Icons.shopping_bag_outlined, size: 17),
      label: const Text('Amazon'),
    );
  }

  Future<void> _openLink(BuildContext context) async {
    final uri = Uri.tryParse(book.link);
    if (uri == null) return;
    final ok = await launchUrl(uri, webOnlyWindowName: '_blank');
    if (ok || !context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Could not open ${uri.toString()}')));
  }
}

class _DeleteBookButton extends ConsumerWidget {
  const _DeleteBookButton({required this.book});

  final NxBook book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OutlinedButton.icon(
      key: ValueKey('delete-book-${book.id}'),
      onPressed: () => _confirmDelete(context, ref),
      icon: const Icon(Icons.delete_outline, size: 17),
      label: const Text('Delete'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.red,
        side: const BorderSide(color: AppColors.line),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete book?'),
          content: Text(
            'Delete "${book.title}" from nx_books and notes. This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !context.mounted) return;

    await ref.read(bookMutationControllerProvider).deleteBook(book);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Deleted ${book.title}')));
  }
}

class _MobileBookDetailPage extends ConsumerWidget {
  const _MobileBookDetailPage({
    required this.bookId,
    required this.onOpenInNotes,
  });

  final int bookId;
  final Future<void> Function(NxBook book) onOpenInNotes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final books = ref.watch(booksProvider);
    final book = switch (books) {
      AsyncData(:final value) =>
        value.where((book) => book.id == bookId).firstOrNull,
      _ => null,
    };
    return Scaffold(
      key: ValueKey('mobile-book-detail-$bookId'),
      appBar: AppBar(
        title: Text(book?.title ?? 'Book information'),
        backgroundColor: AppColors.panel,
        surfaceTintColor: Colors.transparent,
      ),
      body: switch (books) {
        AsyncLoading() => const Center(child: CircularProgressIndicator()),
        AsyncError(:final error) => _ErrorState(
          message: error.toString(),
          onRetry: () => ref.invalidate(booksProvider),
        ),
        AsyncData() when book == null => const Center(
          child: Text('This book is no longer available'),
        ),
        _ => _BookDetail(book: book, onOpenInNotes: onOpenInNotes),
      },
    );
  }
}

class _StateSelector extends ConsumerWidget {
  const _StateSelector({required this.book});

  final NxBook book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        for (final state in BookReadingState.values)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: state == BookReadingState.values.last ? 0 : 5,
              ),
              child: _StateChip(
                key: ValueKey('state-${state.kgqlValue}'),
                state: state,
                active: state == book.readingState,
                onTap: () => ref
                    .read(bookMutationControllerProvider)
                    .changeState(book, state),
              ),
            ),
          ),
      ],
    );
  }
}

class _RankControl extends ConsumerWidget {
  const _RankControl({required this.book});

  final NxBook book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        _StepperButton(
          icon: Icons.remove,
          tooltip: 'Move up',
          onPressed: () =>
              ref.read(bookMutationControllerProvider).moveWithinLane(book, -1),
        ),
        Expanded(
          child: Container(
            height: 36,
            alignment: Alignment.center,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.line),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              '${book.rank ?? '-'}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
        _StepperButton(
          icon: Icons.add,
          tooltip: 'Move down',
          onPressed: () =>
              ref.read(bookMutationControllerProvider).moveWithinLane(book, 1),
        ),
      ],
    );
  }
}

class _ChapterProgressEditor extends ConsumerStatefulWidget {
  const _ChapterProgressEditor({required this.book});

  final NxBook book;

  @override
  ConsumerState<_ChapterProgressEditor> createState() =>
      _ChapterProgressEditorState();
}

class _ChapterProgressEditorState
    extends ConsumerState<_ChapterProgressEditor> {
  late final TextEditingController _totalController;
  late final FocusNode _totalFocusNode;
  double _currentValue = 0;

  @override
  void initState() {
    super.initState();
    _totalController = TextEditingController();
    _totalFocusNode = FocusNode();
    _syncFromBook();
    _totalFocusNode.addListener(_handleTotalFocusChange);
  }

  @override
  void didUpdateWidget(covariant _ChapterProgressEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.book.id != widget.book.id ||
        oldWidget.book.totalChapters != widget.book.totalChapters ||
        oldWidget.book.currentChapter != widget.book.currentChapter) {
      _syncFromBook();
    }
  }

  @override
  void dispose() {
    _totalFocusNode.removeListener(_handleTotalFocusChange);
    _totalFocusNode.dispose();
    _totalController.dispose();
    super.dispose();
  }

  void _syncFromBook() {
    final total = widget.book.totalChapters;
    final current = widget.book.currentChapter ?? 0;
    final text = total == null ? '' : '$total';
    if (_totalController.text != text) {
      _totalController.text = text;
    }
    _currentValue = total == null ? 0 : current.clamp(0, total).toDouble();
  }

  void _handleTotalFocusChange() {
    if (!_totalFocusNode.hasFocus) {
      _saveTotal(_totalController.text);
    }
  }

  Future<void> _saveTotal(String value) async {
    final trimmed = value.trim();
    final parsed = int.tryParse(trimmed);
    final total = parsed == null || parsed <= 0 ? null : parsed;
    final current = total == null
        ? null
        : (widget.book.currentChapter ?? _currentValue.round())
              .clamp(0, total)
              .toInt();
    await ref
        .read(bookMutationControllerProvider)
        .updateChapterProgress(
          widget.book,
          totalChapters: total,
          currentChapter: current,
        );
  }

  Future<void> _saveCurrent(double value) async {
    final total = widget.book.totalChapters;
    if (total == null || total <= 0) return;
    final current = value.round().clamp(0, total).toInt();
    setState(() => _currentValue = current.toDouble());
    await ref
        .read(bookMutationControllerProvider)
        .updateChapterProgress(
          widget.book,
          totalChapters: total,
          currentChapter: current,
        );
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.book.totalChapters;
    final current = total == null
        ? null
        : _currentValue.round().clamp(0, total).toInt();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: ValueKey('book-total-chapters-${widget.book.id}'),
          controller: _totalController,
          focusNode: _totalFocusNode,
          keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Total chapters',
            suffixIcon: _totalController.text.isNotEmpty
                ? IconButton(
                    tooltip: 'Clear chapters',
                    icon: const Icon(
                      Icons.close,
                      size: 16,
                      color: AppColors.faint,
                    ),
                    onPressed: () {
                      _totalController.clear();
                      _saveTotal('');
                    },
                  )
                : null,
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: _saveTotal,
        ),
        if (total != null && total > 0) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Chapter ${current ?? 0} of $total',
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '${((current ?? 0) / total * 100).round()}%',
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          Slider(
            value: (current ?? 0).toDouble(),
            min: 0,
            max: total.toDouble(),
            divisions: total,
            label: '${current ?? 0}',
            onChanged: (value) => setState(() => _currentValue = value),
            onChangeEnd: _saveCurrent,
          ),
        ],
      ],
    );
  }
}

class _TopicTagsEditor extends ConsumerWidget {
  const _TopicTagsEditor({required this.book});

  final NxBook book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final availableTags =
        ref.watch(topicTagsProvider).value ?? const <String>[];
    final selected = book.tags;
    final addable = availableTags
        .where(
          (tag) =>
              !selected.any((item) => item.toLowerCase() == tag.toLowerCase()),
        )
        .toList();

    return Wrap(
      spacing: 5,
      runSpacing: 5,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final tag in selected)
          _Pill(
            tag,
            onRemove: () => ref
                .read(bookMutationControllerProvider)
                .updateTopicTags(
                  book,
                  selected.where((item) => item != tag).toList(),
                ),
          ),
        _AddTopicTagMenu(
          enabled: addable.isNotEmpty,
          tags: addable,
          onSelected: (tag) {
            ref
                .read(bookMutationControllerProvider)
                .updateTopicTags(book, <String>{...selected, tag}.toList());
          },
        ),
        if (selected.isEmpty && addable.isEmpty)
          const Text(
            'No Topic tags',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
      ],
    );
  }
}

class _AddTopicTagMenu extends StatelessWidget {
  const _AddTopicTagMenu({
    required this.enabled,
    required this.tags,
    required this.onSelected,
  });

  final bool enabled;
  final List<String> tags;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Add Topic tag',
      enabled: enabled,
      color: AppColors.panel,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final tag in tags)
          PopupMenuItem<String>(
            value: tag,
            height: 34,
            child: Text(tag, style: const TextStyle(fontSize: 13)),
          ),
      ],
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: enabled ? AppColors.surface : AppColors.subtle,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          child: Icon(
            Icons.add,
            size: 13,
            color: enabled ? AppColors.muted : AppColors.faint,
          ),
        ),
      ),
    );
  }
}

class _StateChip extends StatelessWidget {
  const _StateChip({
    super.key,
    required this.state,
    required this.active,
    required this.onTap,
  });

  final BookReadingState state;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: active ? AppColors.accentSoft : AppColors.surface,
          foregroundColor: active ? AppColors.accent : AppColors.muted,
          side: BorderSide(
            color: active ? const Color(0xffbdd8d3) : AppColors.line,
          ),
        ),
        child: Text(
          state.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _StateDot extends StatelessWidget {
  const _StateDot({required this.state});

  final BookReadingState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: switch (state) {
          BookReadingState.reading => AppColors.accent,
          BookReadingState.toRead => AppColors.blue,
          BookReadingState.read => AppColors.amber,
        },
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 138,
      alignment: Alignment.bottomLeft,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xff273d56),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x24211e18),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Text(
        title,
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w800,
          height: 1.12,
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 32),
      padding: const EdgeInsets.only(bottom: 8),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

String _compactUrl(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null || uri.host.isEmpty) {
    return value;
  }
  final path = uri.pathSegments.take(2).join('/');
  return path.isEmpty ? uri.host : '${uri.host}/$path';
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.label, {this.onRemove});

  final String label;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.subtle,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(5, 2, onRemove == null ? 5 : 2, 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (onRemove != null) ...[
              const SizedBox(width: 2),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onRemove,
                child: const SizedBox(
                  width: 14,
                  height: 14,
                  child: Icon(Icons.close, size: 10, color: AppColors.faint),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 25),
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SmallIconButton extends StatelessWidget {
  const _SmallIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 17),
      color: AppColors.muted,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 26, height: 24),
      style: IconButton.styleFrom(
        minimumSize: const Size(26, 24),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 36,
        height: 36,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
          child: Icon(icon, size: 17),
        ),
      ),
    );
  }
}

class _EmptyLane extends StatelessWidget {
  const _EmptyLane({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(message, style: const TextStyle(color: AppColors.muted)),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.red, size: 32),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppMark extends StatelessWidget {
  const _AppMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.text,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'B',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
      ),
    );
  }
}

Future<void> _showCreateBookDialog(BuildContext context, WidgetRef ref) async {
  final controller = TextEditingController();
  final title = await showDialog<String>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Add Book'),
        content: TextField(
          key: const ValueKey('new-book-title'),
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Title'),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Add'),
          ),
        ],
      );
    },
  );
  controller.dispose();
  if (title == null) return;
  await ref.read(bookMutationControllerProvider).createBook(title: title);
}
