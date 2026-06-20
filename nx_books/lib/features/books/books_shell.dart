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
        final filtered = _filterBooks(rows, query);
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

  List<NxBook> _filterBooks(List<NxBook> books, String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return books;
    return [
      for (final book in books)
        if ('${book.title} ${book.description} ${book.readingState.label} ${book.tags.join(' ')}'
            .toLowerCase()
            .contains(normalized))
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

class _DesktopBookshelf extends StatelessWidget {
  const _DesktopBookshelf({
    required this.books,
    required this.selected,
    required this.onOpenInNotes,
  });

  final List<NxBook> books;
  final NxBook? selected;
  final Future<void> Function(NxBook book) onOpenInNotes;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              const _MainHeader(),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final state in BookReadingState.values) ...[
                        Expanded(
                          child: _BookLane(
                            key: ValueKey('lane-${state.kgqlValue}'),
                            state: state,
                            books: sortedBooksForState(books, state),
                            selectedId: selected?.id,
                          ),
                        ),
                        if (state != BookReadingState.values.last)
                          const SizedBox(width: 14),
                      ],
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

class _MobileBookshelf extends ConsumerWidget {
  const _MobileBookshelf({
    required this.books,
    required this.selected,
    required this.onOpenInNotes,
  });

  final List<NxBook> books;
  final NxBook? selected;
  final Future<void> Function(NxBook book) onOpenInNotes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(mobileStateProvider);
    final lane = sortedBooksForState(books, state);
    return Column(
      children: [
        _MobileTopBar(totalCount: books.length),
        Container(
          color: AppColors.panel,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              for (final item in BookReadingState.values)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: item == BookReadingState.values.last ? 0 : 5,
                    ),
                    child: _StateChip(
                      state: item,
                      active: item == state,
                      onTap: () =>
                          ref.read(mobileStateProvider.notifier).set(item),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              for (final book in lane)
                _BookCard(
                  book: book,
                  selected: selected?.id == book.id,
                  compact: true,
                ),
              if (lane.isEmpty)
                const _EmptyLane(message: 'No books in this state'),
            ],
          ),
        ),
        DecoratedBox(
          decoration: const BoxDecoration(
            color: AppColors.panel,
            border: Border(top: BorderSide(color: AppColors.line)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: selected == null
                  ? const Text(
                      'Select a book',
                      style: TextStyle(color: AppColors.muted),
                    )
                  : _MobileDetail(
                      book: selected!,
                      onOpenInNotes: onOpenInNotes,
                    ),
            ),
          ),
        ),
      ],
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

class _BookLane extends StatelessWidget {
  const _BookLane({
    super.key,
    required this.state,
    required this.books,
    required this.selectedId,
  });

  final BookReadingState state;
  final List<NxBook> books;
  final int? selectedId;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: panelDecoration(color: AppColors.panel),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Row(
              children: [
                _StateDot(state: state),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.label,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _laneSubtitle(state),
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                _CountBadge(count: books.length),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: books.isEmpty
                ? const _EmptyLane(message: 'No books')
                : ListView.builder(
                    padding: const EdgeInsets.all(10),
                    itemCount: books.length,
                    itemBuilder: (context, index) {
                      final book = books[index];
                      return _BookCard(
                        key: ValueKey('book-card-${book.id}'),
                        book: book,
                        selected: selectedId == book.id,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _laneSubtitle(BookReadingState state) {
    return switch (state) {
      BookReadingState.reading => 'Books currently in motion',
      BookReadingState.toRead => 'Ordered queue',
      BookReadingState.read => 'Finished books',
    };
  }
}

class _BookCard extends ConsumerWidget {
  const _BookCard({
    super.key,
    required this.book,
    required this.selected,
    this.compact = false,
  });

  final NxBook book;
  final bool selected;
  final bool compact;

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
          onTap: () =>
              ref.read(selectedBookIdProvider.notifier).select(book.id),
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
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: FilledButton.icon(
                    onPressed: () => onOpenInNotes(row),
                    icon: const Icon(Icons.open_in_new, size: 17),
                    label: const Text('Open in Notes'),
                  ),
                ),
              ],
            ),
    );
  }
}

class _MobileDetail extends StatelessWidget {
  const _MobileDetail({required this.book, required this.onOpenInNotes});

  final NxBook book;
  final Future<void> Function(NxBook book) onOpenInNotes;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                book.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                book.readingState.label,
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: () => onOpenInNotes(book),
          icon: const Icon(Icons.open_in_new, size: 16),
          label: const Text('Notes'),
        ),
      ],
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
          Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ],
      ),
    );
  }
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
