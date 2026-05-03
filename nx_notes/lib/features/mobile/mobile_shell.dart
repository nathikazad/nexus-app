import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_notes/core/theme/app_theme.dart';
import 'package:nx_notes/data/providers.dart';
import 'package:nx_notes/domain/essay/essay.dart';
import 'package:nx_notes/domain/essay/essay_query.dart';
import 'package:nx_notes/domain/essay/essay_result_context.dart';
import 'package:nx_notes/domain/tags/tag_system.dart';
import 'package:nx_notes/features/editor/essay_editor_view.dart';
import 'package:nx_notes/features/navigator/essay_row.dart';
import 'package:nx_notes/features/shell/notes_state.dart';

class MobileShell extends ConsumerWidget {
  const MobileShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(mobileNotesProvider);
    if (state.activeEssayId != null) {
      return _MobileEditor(state: state);
    }
    if (state.showResults && state.resultContext != null) {
      return _MobileResults(contextState: state.resultContext!);
    }
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: const PreferredSize(
        preferredSize: Size.fromHeight(56),
        child: _MobileTopChrome(title: 'nx_notes'),
      ),
      body: switch (state.section) {
        MobileSection.essays => const _MobileHome(),
        MobileSection.tags => const _MobileTags(),
        MobileSection.search => const _MobileSearch(),
      },
      bottomNavigationBar: _MobileBottomNav(section: state.section),
    );
  }
}

class _MobileTopChrome extends StatelessWidget {
  const _MobileTopChrome({required this.title, this.leading, this.trailing});

  final String title;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: const BoxDecoration(
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
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
            ),
            SizedBox(width: 38, child: trailing),
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
        decoration: const BoxDecoration(
          color: AppColors.panel,
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: Row(
          children: <Widget>[
            _MobileNavItem(
              icon: Icons.description_outlined,
              label: 'Essays',
              active: section == MobileSection.essays,
              onTap: () => ref
                  .read(mobileNotesProvider.notifier)
                  .setSection(MobileSection.essays),
            ),
            _MobileNavItem(
              icon: Icons.sell_outlined,
              label: 'Tags',
              active: section == MobileSection.tags,
              onTap: () => ref
                  .read(mobileNotesProvider.notifier)
                  .setSection(MobileSection.tags),
            ),
            _MobileNavItem(
              icon: Icons.search,
              label: 'Search',
              active: section == MobileSection.search,
              onTap: () => ref
                  .read(mobileNotesProvider.notifier)
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
    final pinned = ref.watch(pinnedEssaysProvider).value ?? const <Essay>[];
    final recent = ref.watch(recentEssaysProvider).value ?? const <Essay>[];
    return ListView(
      padding: const EdgeInsets.all(14),
      children: <Widget>[
        TextField(
          style: const TextStyle(fontSize: 13),
          decoration: const InputDecoration(
            hintText: 'Search essays...',
            prefixIcon: Icon(Icons.search, size: 18, color: AppColors.faint),
            prefixIconConstraints: BoxConstraints(minWidth: 34),
          ),
          onChanged: (value) =>
              ref.read(mobileNotesProvider.notifier).setSearchText(value),
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
  final List<Essay> rows;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.faint,
            ),
          ),
        ),
        for (final essay in rows) ...<Widget>[
          EssayRow(
            essay: essay,
            onTap: () =>
                ref.read(mobileNotesProvider.notifier).openEssay(essay.id),
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
    final systems = ref.watch(tagSystemsProvider).value ?? const <TagSystem>[];
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 24),
      children: <Widget>[
        for (final system in systems) ...<Widget>[
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 8),
            child: Text(
              system.name.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.faint,
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
            final filter = EssayTagFilter(
              system: system,
              node: node.name,
              includeDescendants: depth == 0,
            );
            final rows = await ref
                .read(essayRepositoryProvider)
                .listByTag(filter);
            ref
                .read(mobileNotesProvider.notifier)
                .showResults(
                  EssayResultContext(
                    title: '$system: ${node.name}',
                    query: EssayQuery(tagFilters: <EssayTagFilter>[filter]),
                    resultIds: rows.map((essay) => essay.id).toList(),
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
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  '${node.count}',
                  style: const TextStyle(fontSize: 12, color: AppColors.faint),
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

class _MobileSearch extends ConsumerWidget {
  const _MobileSearch();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(mobileNotesProvider);
    final rows =
        ref.watch(essaySearchProvider(state.searchText)).value ??
        const <Essay>[];
    return ListView(
      padding: const EdgeInsets.all(14),
      children: <Widget>[
        TextField(
          autofocus: true,
          style: const TextStyle(fontSize: 13),
          decoration: const InputDecoration(
            hintText: 'Search essays...',
            prefixIcon: Icon(Icons.search, size: 18, color: AppColors.faint),
            prefixIconConstraints: BoxConstraints(minWidth: 34),
          ),
          onChanged: (value) =>
              ref.read(mobileNotesProvider.notifier).setSearchText(value),
        ),
        const SizedBox(height: 22),
        Text(
          state.searchText.isEmpty ? 'TYPE TO SEARCH' : 'RESULTS',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.faint,
          ),
        ),
        const SizedBox(height: 8),
        for (final essay in rows) ...<Widget>[
          EssayRow(
            essay: essay,
            onTap: () => ref
                .read(mobileNotesProvider.notifier)
                .openEssay(
                  essay.id,
                  context: EssayResultContext(
                    title: 'Search: ${state.searchText}',
                    query: EssayQuery(searchText: state.searchText),
                    resultIds: rows.map((row) => row.id).toList(),
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

  final EssayResultContext contextState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = contextState.resultIds
        .map((id) => ref.watch(essayByIdProvider(id)).value)
        .whereType<Essay>()
        .toList();
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: _MobileTopChrome(
          title: contextState.title,
          leading: IconButton(
            onPressed: () => ref.read(mobileNotesProvider.notifier).back(),
            icon: const Icon(
              Icons.arrow_back,
              size: 20,
              color: AppColors.muted,
            ),
          ),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(14),
        itemCount: rows.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final essay = rows[index];
          return EssayRow(
            essay: essay,
            onTap: () => ref
                .read(mobileNotesProvider.notifier)
                .openEssay(essay.id, context: contextState),
          );
        },
      ),
    );
  }
}

class _MobileEditor extends ConsumerWidget {
  const _MobileEditor({required this.state});

  final MobileNotesState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final essayId = state.activeEssayId!;
    final essay = ref.watch(essayByIdProvider(essayId)).value;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: _MobileTopChrome(
          title: essay?.title ?? 'Editor',
          leading: IconButton(
            onPressed: () => ref.read(mobileNotesProvider.notifier).back(),
            icon: const Icon(
              Icons.arrow_back,
              size: 20,
              color: AppColors.muted,
            ),
          ),
          trailing: IconButton(
            onPressed: () => _showEssaySheet(context, ref, essayId),
            icon: const Icon(
              Icons.more_horiz,
              size: 22,
              color: AppColors.muted,
            ),
          ),
        ),
      ),
      body: EssayEditorView(
        essayId: essayId,
        contextBar: state.resultContext == null
            ? null
            : EditorContextBar(
                resultContext: state.resultContext!,
                activeEssayId: essayId,
                onBack: () => ref.read(mobileNotesProvider.notifier).back(),
                onClear: () {},
              ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: const BoxDecoration(
            color: AppColors.panel,
            border: Border(top: BorderSide(color: AppColors.line)),
          ),
          child: const Row(
            children: <Widget>[
              _ToolButton(icon: Icons.format_bold),
              _ToolButton(icon: Icons.format_italic),
              _ToolDivider(),
              _ToolButton(icon: Icons.format_list_bulleted),
              _ToolButton(icon: Icons.link),
              Spacer(),
              _MetadataButton(),
            ],
          ),
        ),
      ),
    );
  }

  void _showEssaySheet(BuildContext context, WidgetRef ref, int essayId) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.panel,
      builder: (context) {
        final essay = ref.watch(essayByIdProvider(essayId)).value;
        final snaps =
            ref.watch(essaySnapshotsProvider(essayId)).value ?? const [];
        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
          children: <Widget>[
            const Text(
              'Details',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            if (essay != null) ...<Widget>[
              _SheetPair(label: 'Status', value: essay.status),
              _SheetPair(
                label: 'Tags',
                value: [...essay.topics, ...essay.areaTags].join(', '),
              ),
              _SheetPair(
                label: 'Document',
                value:
                    '${essay.wordCount} words · Version ${essay.versionNumber}',
              ),
              const Divider(height: 28),
              const Text(
                'Links',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 8),
              for (final link in essay.links)
                _SheetPair(label: link.modelType, value: link.name),
              const Divider(height: 28),
              const Text(
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

class _ToolButton extends StatelessWidget {
  const _ToolButton({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Icon(icon, size: 20, color: AppColors.muted),
    );
  }
}

class _ToolDivider extends StatelessWidget {
  const _ToolDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 22,
      margin: const EdgeInsets.only(right: 12),
      color: AppColors.line,
    );
  }
}

class _MetadataButton extends StatelessWidget {
  const _MetadataButton();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.subtle,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          children: <Widget>[
            Icon(Icons.info_outline, size: 14, color: AppColors.muted),
            SizedBox(width: 5),
            Text(
              'Metadata',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
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
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, color: AppColors.text),
            ),
          ),
        ],
      ),
    );
  }
}
