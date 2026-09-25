import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nx_docs/account/account_providers.dart';
import 'package:nx_docs/workspace/mobile/mobile_create_button.dart';
import 'package:nx_docs/workspace/desktop/desktop_workspace.dart';
import 'package:nx_docs/documents/document_providers.dart';
import 'package:nx_docs/library/library_providers.dart';
import 'package:nx_docs/app/theme.dart';
import 'package:nx_docs/documents/document_models.dart';
import 'package:nx_docs/tags/tag_system.dart';
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
      pageKey = 'documents';
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
          title: 'Nx Docs',
          leading: const MobileCreateButton(),
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
      body: const _MobileHome(),
    );
  }
}

class _MobilePageTransition extends StatelessWidget {
  const _MobilePageTransition({
    required this.pageKey,
    required this.direction,
    required this.child,
  });

  final Object pageKey;
  final MobileNavigationDirection direction;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final offset = direction == MobileNavigationDirection.backward ? -.08 : .08;
    // AnimatedSwitcher keeps the outgoing editor mounted in place. Rebuilding
    // it in a second slot would discard selection and pending typing saves.
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeOutCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: Offset(offset, 0),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: KeyedSubtree(key: ValueKey(pageKey), child: child),
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
            SizedBox(width: 48, child: leading),
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

final _mobileTagFilterProvider =
    NotifierProvider<_MobileTagFilter, DocumentTagFilter?>(
      _MobileTagFilter.new,
    );

class _MobileTagFilter extends Notifier<DocumentTagFilter?> {
  @override
  DocumentTagFilter? build() => null;
  void select(DocumentTagFilter? filter) => state = filter;
}

class _MobileHome extends ConsumerStatefulWidget {
  const _MobileHome();

  @override
  ConsumerState<_MobileHome> createState() => _MobileHomeState();
}

class _MobileHomeState extends ConsumerState<_MobileHome> {
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(
      text: ref.read(mobileWorkspaceProvider).searchText,
    );
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _showFilters() async {
    FocusScope.of(context).unfocus();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final systems = ref.watch(offlineTagSystemsProvider);
          final selected = ref.watch(_mobileTagFilterProvider);
          return SafeArea(
            top: false,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * .7,
              ),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.all(20),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Filter documents',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close filters',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('All tags'),
                    trailing: selected == null ? const Icon(Icons.check) : null,
                    onTap: () {
                      ref.read(_mobileTagFilterProvider.notifier).select(null);
                      Navigator.pop(context);
                    },
                  ),
                  if (systems.isLoading) const LinearProgressIndicator(),
                  if (systems.hasError)
                    const Text('Could not load tags. Try again.'),
                  if (systems.hasValue && systems.value!.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'Tags added to your documents will appear here.',
                      ),
                    ),
                  for (final system
                      in systems.value ?? const <TagSystem>[]) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 16, bottom: 8),
                      child: Text(
                        system.name,
                        style: TextStyle(
                          color: AppColors.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    for (final node in system.nodes)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(node.name),
                        trailing:
                            selected?.system == system.name &&
                                selected?.node == node.name
                            ? const Icon(Icons.check)
                            : Text(
                                '${node.count}',
                                style: TextStyle(color: AppColors.faint),
                              ),
                        onTap: () {
                          ref
                              .read(_mobileTagFilterProvider.notifier)
                              .select(
                                DocumentTagFilter(
                                  system: system.name,
                                  node: node.name,
                                ),
                              );
                          Navigator.pop(context);
                        },
                      ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(mobileWorkspaceProvider).searchText;
    final filter = ref.watch(_mobileTagFilterProvider);
    final filtering = query.trim().isNotEmpty || filter != null;
    final pinned =
        ref.watch(offlinePinnedDocumentsProvider).value ?? const <NxDocument>[];
    final recent =
        ref.watch(offlineRecentDocumentsProvider).value ?? const <NxDocument>[];
    final matches = filtering
        ? ref.watch(
            query.trim().isEmpty
                ? offlineAllDocumentsProvider
                : offlineDocumentSearchProvider(query),
          )
        : const AsyncValue<List<NxDocument>>.data([]);
    final rows = (matches.value ?? const <NxDocument>[])
        .where(
          (document) =>
              filter == null ||
              (document.tagsBySystem[filter.system] ?? const <String>[])
                  .contains(filter.node),
        )
        .toList();
    return ListView(
      padding: const EdgeInsets.all(14),
      children: <Widget>[
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _search,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search documents...',
                  prefixIcon: Icon(
                    Icons.search,
                    size: 20,
                    color: AppColors.faint,
                  ),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            _search.clear();
                            ref
                                .read(mobileWorkspaceProvider.notifier)
                                .setSearchText('');
                          },
                        ),
                ),
                onChanged: ref
                    .read(mobileWorkspaceProvider.notifier)
                    .setSearchText,
              ),
            ),
            const SizedBox(width: 10),
            IconButton.filledTonal(
              tooltip: 'Filter documents',
              style: IconButton.styleFrom(
                minimumSize: const Size.square(48),
                backgroundColor: filter == null
                    ? AppColors.subtle
                    : AppColors.hover,
                foregroundColor: filter == null
                    ? AppColors.muted
                    : AppColors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _showFilters,
              icon: Icon(filter == null ? Icons.tune : Icons.filter_alt),
            ),
          ],
        ),
        if (filter != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: InputChip(
                label: Text('${filter.system}: ${filter.node}'),
                onDeleted: () =>
                    ref.read(_mobileTagFilterProvider.notifier).select(null),
              ),
            ),
          ),
        const SizedBox(height: 22),
        if (filtering) ...[
          if (matches.isLoading) const LinearProgressIndicator(),
          if (matches.hasError)
            const Text('Could not load documents. Try again.')
          else if (!matches.isLoading && rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No documents match',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted),
              ),
            ),
          _MobileSection(title: 'Results', rows: rows),
        ] else ...[
          if (pinned.isNotEmpty) ...[
            _MobileSection(title: 'Pinned', rows: pinned.take(5).toList()),
            const SizedBox(height: 22),
          ],
          _MobileSection(title: 'Recent', rows: recent),
        ],
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
            tooltip: 'Document details',
            onPressed: () => showDocumentInspectorSheet(context, documentId),
            icon: Icon(Icons.more_horiz, size: 22, color: AppColors.muted),
          ),
        ),
      ),
      body: DocumentEditorView(
        documentId: documentId,
        interactionMode: DocumentInteractionMode.edit,
        showDocumentTitle: true,
        showCompanion: false,
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
}
