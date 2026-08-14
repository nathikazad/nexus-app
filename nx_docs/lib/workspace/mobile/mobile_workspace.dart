import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nx_docs/account/account_providers.dart';
import 'package:nx_docs/documents/document_providers.dart';
import 'package:nx_docs/library/library_providers.dart';
import 'package:nx_docs/app/theme.dart';
import 'package:nx_docs/documents/document_data_providers.dart';
import 'package:nx_docs/documents/document_models.dart';
import 'package:nx_docs/tags/tag_system.dart';
import 'package:nx_docs/books/book_shelf.dart';
import 'package:nx_docs/documents/editor/document_editor_view.dart';
import 'package:nx_docs/library/document_row.dart';
import 'package:nx_docs/settings/settings_button.dart';
import 'package:nx_docs/workspace/workspace_state.dart';

class MobileWorkspace extends ConsumerWidget {
  const MobileWorkspace({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(mobileWorkspaceProvider);
    final Widget page;
    final Object pageKey;
    if (state.activeDocumentId != null) {
      pageKey = 'document-${state.activeDocumentId}';
      page = _MobileEditor(state: state);
    } else if (state.showResults && state.resultContext != null) {
      pageKey = 'results-${state.resultContext.hashCode}';
      page = _MobileResults(contextState: state.resultContext!);
    } else {
      pageKey = 'section-${state.section.name}';
      page = _MobileSectionPage(state: state);
    }
    return _MobilePageTransition(
      pageKey: pageKey,
      direction: state.navigationDirection,
      child: page,
    );
  }
}

class _MobileSectionPage extends ConsumerWidget {
  const _MobileSectionPage({required this.state});

  final MobileWorkspaceState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: _MobileTopChrome(
          title: 'Nexus Docs',
          trailingWidth: 76,
          trailing: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              IconButton(
                tooltip: 'Log out',
                onPressed: () async {
                  await ref.read(accountLogoutProvider)();
                  if (context.mounted) context.go('/login');
                },
                style: IconButton.styleFrom(
                  minimumSize: const Size.square(34),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: Icon(Icons.logout, size: 20, color: AppColors.muted),
                splashRadius: 18,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 34,
                  height: 34,
                ),
              ),
              const DocsSettingsButton(),
            ],
          ),
        ),
      ),
      body: switch (state.section) {
        MobileSection.documents => const _MobileHome(),
        MobileSection.books => const _MobileBooks(),
        MobileSection.tags => const _MobileTags(),
        MobileSection.search => const _MobileSearch(),
      },
      bottomNavigationBar: _MobileBottomNav(section: state.section),
    );
  }
}

class _MobilePageTransition extends StatefulWidget {
  const _MobilePageTransition({
    required this.pageKey,
    required this.direction,
    required this.child,
  });

  final Object pageKey;
  final MobileNavigationDirection direction;
  final Widget child;

  @override
  State<_MobilePageTransition> createState() => _MobilePageTransitionState();
}

class _MobilePageTransitionState extends State<_MobilePageTransition>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 240);

  late final AnimationController _controller;
  late Widget _currentChild;
  Widget? _outgoingChild;
  late Object _currentKey;
  MobileNavigationDirection _direction = MobileNavigationDirection.neutral;

  @override
  void initState() {
    super.initState();
    _currentKey = widget.pageKey;
    _currentChild = widget.child;
    _controller = AnimationController(vsync: this, duration: _duration)
      ..value = 1
      ..addStatusListener(_handleAnimationStatus);
  }

  @override
  void didUpdateWidget(covariant _MobilePageTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_currentKey == widget.pageKey) {
      _currentChild = widget.child;
      return;
    }
    _outgoingChild = _currentChild;
    _currentChild = widget.child;
    _currentKey = widget.pageKey;
    _direction = widget.direction;
    _controller.forward(from: 0);
  }

  void _handleAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed &&
        _outgoingChild != null &&
        mounted) {
      setState(() => _outgoingChild = null);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final value = Curves.easeOutCubic.transform(_controller.value);
        final direction = switch (_direction) {
          MobileNavigationDirection.forward => 1.0,
          MobileNavigationDirection.backward => -1.0,
          MobileNavigationDirection.neutral => 0.0,
        };
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (_outgoingChild != null)
              IgnorePointer(
                child: ExcludeSemantics(
                  child: Opacity(
                    opacity: 1 - (0.35 * value),
                    child: FractionalTranslation(
                      translation: Offset(-direction * 0.18 * value, 0),
                      child: _outgoingChild!,
                    ),
                  ),
                ),
              ),
            Opacity(
              opacity: 0.65 + (0.35 * value),
              child: FractionalTranslation(
                translation: Offset(direction * 0.18 * (1 - value), 0),
                child: _currentChild,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MobileTopChrome extends StatelessWidget {
  const _MobileTopChrome({
    required this.title,
    this.leading,
    this.trailing,
    this.trailingWidth = 38,
  });

  final String title;
  final Widget? leading;
  final Widget? trailing;
  final double trailingWidth;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.panel,
          border: Border(bottom: BorderSide(color: AppColors.line)),
        ),
        child: Row(
          children: <Widget>[
            SizedBox(width: 38, child: leading),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
            ),
            SizedBox(width: trailingWidth, child: trailing),
          ],
        ),
      ),
    );
  }
}

class _MobileBottomNav extends ConsumerWidget {
  const _MobileBottomNav({required this.section});

  final MobileSection section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      top: false,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.panel,
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: Row(
          children: <Widget>[
            _MobileNavItem(
              icon: Icons.description_outlined,
              label: 'Docs',
              active: section == MobileSection.documents,
              onTap: () => ref
                  .read(mobileWorkspaceProvider.notifier)
                  .setSection(MobileSection.documents),
            ),
            _MobileNavItem(
              icon: Icons.menu_book_outlined,
              label: 'Books',
              active: section == MobileSection.books,
              onTap: () => ref
                  .read(mobileWorkspaceProvider.notifier)
                  .setSection(MobileSection.books),
            ),
            _MobileNavItem(
              icon: Icons.sell_outlined,
              label: 'Tags',
              active: section == MobileSection.tags,
              onTap: () => ref
                  .read(mobileWorkspaceProvider.notifier)
                  .setSection(MobileSection.tags),
            ),
            _MobileNavItem(
              icon: Icons.search,
              label: 'Search',
              active: section == MobileSection.search,
              onTap: () => ref
                  .read(mobileWorkspaceProvider.notifier)
                  .setSection(MobileSection.search),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileNavItem extends StatelessWidget {
  const _MobileNavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              icon,
              size: 21,
              color: active ? AppColors.text : AppColors.faint,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: active ? AppColors.text : AppColors.faint,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileHome extends ConsumerWidget {
  const _MobileHome();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pinned =
        ref.watch(offlinePinnedDocumentsProvider).value ?? const <NxDocument>[];
    final recent =
        ref.watch(offlineRecentDocumentsProvider).value ?? const <NxDocument>[];
    return ListView(
      padding: const EdgeInsets.all(14),
      children: <Widget>[
        TextField(
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Search documents...',
            prefixIcon: Icon(Icons.search, size: 18, color: AppColors.faint),
            prefixIconConstraints: const BoxConstraints(minWidth: 34),
          ),
          onChanged: (value) =>
              ref.read(mobileWorkspaceProvider.notifier).setSearchText(value),
        ),
        const SizedBox(height: 22),
        _MobileSection(title: 'Pinned', rows: pinned.take(5).toList()),
        const SizedBox(height: 22),
        _MobileSection(title: 'Recent', rows: recent.take(5).toList()),
      ],
    );
  }
}

class _MobileSection extends ConsumerWidget {
  const _MobileSection({required this.title, required this.rows});

  final String title;
  final List<NxDocument> rows;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.faint,
            ),
          ),
        ),
        for (final document in rows) ...<Widget>[
          DocumentRow(
            document: document,
            onTap: () => ref
                .read(mobileWorkspaceProvider.notifier)
                .openDocument(document.id),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _MobileBooks extends ConsumerStatefulWidget {
  const _MobileBooks();

  @override
  ConsumerState<_MobileBooks> createState() => _MobileBooksState();
}

class _MobileBooksState extends ConsumerState<_MobileBooks> {
  BookCollectionView _collection = BookCollectionView.toRead;

  @override
  Widget build(BuildContext context) {
    final books = ref.watch(offlineBooksProvider).value ?? const <NxDocument>[];
    final reading = booksForReadingState(books, 'reading');
    final collection = booksForReadingState(books, _collection.value);
    return ListView(
      key: const ValueKey<String>('mobile-book-sections'),
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 24),
      children: <Widget>[
        BookShelfSectionHeader(
          title: 'Currently Reading',
          count: reading.length,
        ),
        const SizedBox(height: 10),
        _MobileBookRows(
          rows: reading,
          emptyMessage: 'No books currently in progress',
        ),
        const SizedBox(height: 24),
        BookShelfSectionHeader(
          title: '',
          count: collection.length,
          trailing: BookCollectionSwitch(
            value: _collection,
            onChanged: (value) => setState(() => _collection = value),
          ),
        ),
        const SizedBox(height: 10),
        _MobileBookRows(
          rows: collection,
          emptyMessage: _collection == BookCollectionView.toRead
              ? 'No books waiting to be read'
              : 'No finished books',
        ),
      ],
    );
  }
}

class _MobileBookRows extends ConsumerWidget {
  const _MobileBookRows({required this.rows, required this.emptyMessage});

  final List<NxDocument> rows;
  final String emptyMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (rows.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
        decoration: BoxDecoration(
          color: AppColors.panel,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          emptyMessage,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: AppColors.faint),
        ),
      );
    }
    return Column(
      children: <Widget>[
        for (final document in rows) ...<Widget>[
          DocumentRow(
            key: ValueKey<String>('mobile-book-${document.id}'),
            document: document,
            onTap: () => ref
                .read(mobileWorkspaceProvider.notifier)
                .openDocument(document.id),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _MobileTags extends ConsumerWidget {
  const _MobileTags();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final systems =
        ref.watch(offlineTagSystemsProvider).value ?? const <TagSystem>[];
    final documents =
        ref.watch(offlineAllDocumentsProvider).value ?? const <NxDocument>[];
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 24),
      children: <Widget>[
        for (final system in systems) ...<Widget>[
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 8),
            child: Text(
              system.name.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.faint,
              ),
            ),
          ),
          for (final node in system.nodes)
            ..._tagRows(ref, system.name, node, documents),
          const SizedBox(height: 22),
        ],
      ],
    );
  }

  List<Widget> _tagRows(
    WidgetRef ref,
    String system,
    TagNode node,
    List<NxDocument> documents, [
    int depth = 0,
  ]) {
    return <Widget>[
      Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () {
            final rows = documents
                .where((document) {
                  final tags =
                      document.tagsBySystem[system] ?? const <String>[];
                  return tags.contains(node.name);
                })
                .toList(growable: false);
            ref
                .read(mobileWorkspaceProvider.notifier)
                .showResults(
                  DocumentResultContext(
                    title: '$system: ${node.name}',
                    query: DocumentQuery(
                      tagFilters: <DocumentTagFilter>[
                        DocumentTagFilter(system: system, node: node.name),
                      ],
                    ),
                    resultIds: rows.map((document) => document.id).toList(),
                    results: rows,
                  ),
                );
          },
          child: Padding(
            padding: EdgeInsets.fromLTRB(8 + depth * 16.0, 9, 8, 9),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    node.name,
                    style: TextStyle(
                      fontSize: 14,
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
        ..._tagRows(ref, system, child, documents, depth + 1),
    ];
  }
}

class _MobileSearch extends ConsumerWidget {
  const _MobileSearch();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(mobileWorkspaceProvider);
    final rows =
        ref.watch(offlineDocumentSearchProvider(state.searchText)).value ??
        const <NxDocument>[];
    return ListView(
      padding: const EdgeInsets.all(14),
      children: <Widget>[
        TextField(
          autofocus: true,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Search documents...',
            prefixIcon: Icon(Icons.search, size: 18, color: AppColors.faint),
            prefixIconConstraints: const BoxConstraints(minWidth: 34),
          ),
          onChanged: (value) =>
              ref.read(mobileWorkspaceProvider.notifier).setSearchText(value),
        ),
        const SizedBox(height: 22),
        Text(
          state.searchText.isEmpty ? 'TYPE TO SEARCH' : 'RESULTS',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.faint,
          ),
        ),
        const SizedBox(height: 8),
        for (final document in rows) ...<Widget>[
          DocumentRow(
            document: document,
            onTap: () => ref
                .read(mobileWorkspaceProvider.notifier)
                .openDocument(
                  document.id,
                  context: DocumentResultContext(
                    title: 'Search: ${state.searchText}',
                    query: DocumentQuery(searchText: state.searchText),
                    resultIds: rows.map((row) => row.id).toList(),
                    results: rows,
                  ),
                ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _MobileResults extends ConsumerWidget {
  const _MobileResults({required this.contextState});

  final DocumentResultContext contextState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = contextState.results;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: _MobileTopChrome(
          title: contextState.title,
          leading: IconButton(
            onPressed: () => ref.read(mobileWorkspaceProvider.notifier).back(),
            icon: Icon(Icons.arrow_back, size: 20, color: AppColors.muted),
          ),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(14),
        itemCount: rows.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final document = rows[index];
          return DocumentRow(
            document: document,
            onTap: () => ref
                .read(mobileWorkspaceProvider.notifier)
                .openDocument(document.id, context: contextState),
          );
        },
      ),
    );
  }
}

class _MobileEditor extends ConsumerWidget {
  const _MobileEditor({required this.state});

  final MobileWorkspaceState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documentId = state.activeDocumentId!;
    final document = ref.watch(offlineDocumentProvider(documentId)).value;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: _MobileTopChrome(
          title: document?.title ?? 'Editor',
          leading: IconButton(
            onPressed: () => ref.read(mobileWorkspaceProvider.notifier).back(),
            icon: Icon(Icons.arrow_back, size: 20, color: AppColors.muted),
          ),
          trailing: IconButton(
            onPressed: () =>
                _showDocumentSheet(context, ref, documentId, document),
            icon: Icon(Icons.more_horiz, size: 22, color: AppColors.muted),
          ),
        ),
      ),
      body: DocumentEditorView(
        documentId: documentId,
        interactionMode: DocumentInteractionMode.highlightOnly,
        showDocumentTitle: false,
        horizontalPadding: 16,
        contentTopPadding: 12,
        onOpenDocumentLink: (linkedDocumentId) => ref
            .read(mobileWorkspaceProvider.notifier)
            .openDocumentFromLink(linkedDocumentId),
        contextBar: state.resultContext == null
            ? null
            : EditorContextBar(
                resultContext: state.resultContext!,
                activeDocumentId: documentId,
                onBack: () => ref.read(mobileWorkspaceProvider.notifier).back(),
                onClear: () {},
              ),
      ),
    );
  }

  void _showDocumentSheet(
    BuildContext context,
    WidgetRef ref,
    int documentId,
    NxDocument? cachedDocument,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.panel,
      builder: (context) {
        final document = cachedDocument;
        final snaps =
            ref.watch(documentSnapshotsProvider(documentId)).value ?? const [];
        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
          children: <Widget>[
            const Text(
              'Details',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            if (document != null) ...<Widget>[
              _SheetPair(label: 'Status', value: document.status),
              _SheetPair(
                label: 'Tags',
                value: [...document.topics, ...document.areaTags].join(', '),
              ),
              _SheetPair(
                label: 'Document',
                value:
                    '${document.wordCount} words · Version ${document.versionNumber}',
              ),
              const Divider(height: 28),
              Text(
                'Links',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 8),
              for (final link in document.links)
                _SheetPair(label: link.modelType, value: link.name),
              const Divider(height: 28),
              Text(
                'History',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 8),
              for (final snap in snaps)
                _SheetPair(
                  label: 'Version ${snap.versionNumber}',
                  value: snap.changeSummary,
                ),
            ],
          ],
        );
      },
    );
  }
}

class _SheetPair extends StatelessWidget {
  const _SheetPair({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 86,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 12, color: AppColors.text),
            ),
          ),
        ],
      ),
    );
  }
}
