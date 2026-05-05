import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_notes/core/theme/app_theme.dart';
import 'package:nx_notes/data/providers.dart';
import 'package:nx_notes/domain/essay/essay.dart';
import 'package:nx_notes/domain/essay/essay_query.dart';
import 'package:nx_notes/domain/tags/tag_system.dart';
import 'package:nx_notes/features/editor/essay_editor_view.dart';
import 'package:nx_notes/features/navigator/essay_row.dart';
import 'package:nx_notes/features/shell/notes_state.dart';

const double _sidebarWidth = 256;
const double _inspectorWidth = 288;

class DesktopShell extends ConsumerWidget {
  const DesktopShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(desktopWorkspaceProvider);
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: <Widget>[
          Row(
            children: <Widget>[
              const SizedBox(width: _sidebarWidth, child: _DesktopSidebar()),
              Expanded(child: _DesktopEditorWorkspace(workspace: workspace)),
              SizedBox(
                width: _inspectorWidth,
                child: _DesktopInspector(essayId: workspace.activeEssayId),
              ),
            ],
          ),
          if (workspace.hasOverlay) _DesktopResultOverlay(workspace: workspace),
        ],
      ),
    );
  }
}

class _DesktopSidebar extends ConsumerStatefulWidget {
  const _DesktopSidebar();

  @override
  ConsumerState<_DesktopSidebar> createState() => _DesktopSidebarState();
}

class _DesktopSidebarState extends ConsumerState<_DesktopSidebar> {
  bool _createOpen = false;

  @override
  Widget build(BuildContext context) {
    final workspace = ref.watch(desktopWorkspaceProvider);
    final recent = ref.watch(recentEssaysProvider);
    final pinned = ref.watch(pinnedEssaysProvider);
    final tagSystems = ref.watch(tagSystemsProvider);
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.sidebar,
        border: Border(right: BorderSide(color: AppColors.line)),
      ),
      child: Column(
        children: <Widget>[
          SizedBox(
            height: 48,
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: AppColors.line)),
                  ),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.text,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'N',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'nx_notes',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      _IconSquareButton(
                        icon: Icons.add,
                        onPressed: () =>
                            setState(() => _createOpen = !_createOpen),
                      ),
                    ],
                  ),
                ),
                if (_createOpen)
                  Positioned(
                    top: 40,
                    right: 12,
                    child: _CreateEssayMenu(
                      onCreate: (topic) async {
                        final essay = await ref
                            .read(essayRepositoryProvider)
                            .create(topic: topic);
                        ref.invalidate(recentEssaysProvider);
                        ref.invalidate(pinnedEssaysProvider);
                        ref.invalidate(tagSystemsProvider);
                        ref
                            .read(desktopWorkspaceProvider.notifier)
                            .openEssay(essay.id);
                        setState(() => _createOpen = false);
                      },
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
            child: _SearchField(
              onSubmitted: (value) async {
                final rows = await ref
                    .read(essayRepositoryProvider)
                    .search(value);
                ref
                    .read(desktopWorkspaceProvider.notifier)
                    .showOverlay(
                      title: 'Search: $value',
                      query: EssayQuery(searchText: value),
                      resultIds: rows.map((essay) => essay.id).toList(),
                    );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
            child: Row(
              children: <Widget>[
                _SidebarTabButton(
                  label: 'Essays',
                  active: workspace.sidebarTab == SidebarTab.essays,
                  onTap: () => ref
                      .read(desktopWorkspaceProvider.notifier)
                      .setSidebarTab(SidebarTab.essays),
                ),
                _SidebarTabButton(
                  label: 'Tags',
                  active: workspace.sidebarTab == SidebarTab.tags,
                  onTap: () => ref
                      .read(desktopWorkspaceProvider.notifier)
                      .setSidebarTab(SidebarTab.tags),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: workspace.sidebarTab == SidebarTab.essays
                ? _SidebarEssays(recent: recent, pinned: pinned)
                : _SidebarTags(tagSystems: tagSystems),
          ),
        ],
      ),
    );
  }
}

class _IconSquareButton extends StatelessWidget {
  const _IconSquareButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.panel,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onPressed,
        child: Container(
          width: 26,
          height: 24,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(icon, size: 16, color: AppColors.muted),
        ),
      ),
    );
  }
}

class _CreateEssayMenu extends ConsumerWidget {
  const _CreateEssayMenu({required this.onCreate});

  final ValueChanged<String> onCreate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagSystems =
        ref.watch(tagSystemsProvider).value ?? const <TagSystem>[];
    final topics = tagSystems
        .where((system) => system.name == 'Topic')
        .expand((system) => system.nodes)
        .map((node) => node.name)
        .toList();
    return Material(
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      color: AppColors.panel,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 192,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(6),
        ),
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 6, 12, 6),
              child: Text(
                'SELECT TOPIC',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.faint,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            for (final topic in topics)
              InkWell(
                onTap: () => onCreate(topic),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          topic,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: AppColors.faint,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.onSubmitted});

  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      style: const TextStyle(fontSize: 13),
      decoration: const InputDecoration(
        hintText: 'Search essays...',
        prefixIcon: Icon(Icons.search, size: 18, color: AppColors.faint),
        prefixIconConstraints: BoxConstraints(minWidth: 34),
      ),
      onSubmitted: onSubmitted,
    );
  }
}

class _SidebarTabButton extends StatelessWidget {
  const _SidebarTabButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: active
            ? const BoxDecoration(
                color: AppColors.panel,
                border: Border(
                  top: BorderSide(color: AppColors.line),
                  left: BorderSide(color: AppColors.line),
                  right: BorderSide(color: AppColors.line),
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
              )
            : null,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: active ? AppColors.text : AppColors.muted,
          ),
        ),
      ),
    );
  }
}

class _SidebarEssays extends ConsumerWidget {
  const _SidebarEssays({required this.recent, required this.pinned});

  final AsyncValue<List<Essay>> recent;
  final AsyncValue<List<Essay>> pinned;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: <Widget>[
        _SidebarSection(
          title: 'Pinned',
          onTitleTap: () async {
            final rows = await ref
                .read(essayRepositoryProvider)
                .listPinned(limit: 50);
            ref
                .read(desktopWorkspaceProvider.notifier)
                .showOverlay(
                  title: 'Pinned essays',
                  query: const EssayQuery(pinnedOnly: true),
                  resultIds: rows.map((essay) => essay.id).toList(),
                );
          },
          rows: pinned.value?.take(5).toList() ?? const <Essay>[],
          pinned: true,
        ),
        const SizedBox(height: 22),
        _SidebarSection(
          title: 'Recent',
          onTitleTap: () async {
            final rows = await ref
                .read(essayRepositoryProvider)
                .listRecent(limit: 50);
            ref
                .read(desktopWorkspaceProvider.notifier)
                .showOverlay(
                  title: 'Recent essays',
                  query: const EssayQuery(),
                  resultIds: rows.map((essay) => essay.id).toList(),
                );
          },
          rows: recent.value?.take(5).toList() ?? const <Essay>[],
        ),
      ],
    );
  }
}

class _SidebarSection extends ConsumerWidget {
  const _SidebarSection({
    required this.title,
    required this.rows,
    required this.onTitleTap,
    this.pinned = false,
  });

  final String title;
  final List<Essay> rows;
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
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.faint,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        for (final essay in rows)
          _SidebarEssayLink(
            essay: essay,
            pinned: pinned,
            onTap: () =>
                ref.read(desktopWorkspaceProvider.notifier).openEssay(essay.id),
          ),
      ],
    );
  }
}

class _SidebarEssayLink extends StatelessWidget {
  const _SidebarEssayLink({
    required this.essay,
    required this.onTap,
    this.pinned = false,
  });

  final Essay essay;
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
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(
                    Icons.push_pin_outlined,
                    size: 15,
                    color: AppColors.faint,
                  ),
                ),
              Expanded(
                child: Text(
                  essay.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
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
              style: const TextStyle(
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
            final filter = EssayTagFilter(
              system: system,
              node: node.name,
              includeDescendants: depth == 0,
            );
            final rows = await ref
                .read(essayRepositoryProvider)
                .listByTag(filter);
            ref
                .read(desktopWorkspaceProvider.notifier)
                .showOverlay(
                  title: '$system: ${node.name}',
                  query: EssayQuery(tagFilters: <EssayTagFilter>[filter]),
                  resultIds: rows.map((essay) => essay.id).toList(),
                );
          },
          child: Padding(
            padding: EdgeInsets.fromLTRB(8 + depth * 14.0, 7, 8, 7),
            child: Row(
              children: <Widget>[
                if (depth == 0 && node.children.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
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
                    style: const TextStyle(
                      fontSize: 13,
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

class _DesktopEditorWorkspace extends ConsumerWidget {
  const _DesktopEditorWorkspace({required this.workspace});

  final DesktopWorkspaceState workspace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeEssayId = workspace.activeEssayId;
    return Column(
      children: <Widget>[
        Container(
          height: 40,
          decoration: const BoxDecoration(
            color: AppColors.sidebar,
            border: Border(bottom: BorderSide(color: AppColors.line)),
          ),
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
                ),
            onClear: () => ref
                .read(desktopWorkspaceProvider.notifier)
                .clearActiveContext(),
          ),
        Expanded(
          child: activeEssayId == null
              ? const _NoEssaySelected()
              : EssayEditorView(essayId: activeEssayId),
        ),
      ],
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

class _DesktopInspector extends ConsumerWidget {
  const _DesktopInspector({required this.essayId});

  final int? essayId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = essayId;
    final essay = id == null ? null : ref.watch(essayByIdProvider(id)).value;
    final snaps = id == null
        ? const []
        : ref.watch(essaySnapshotsProvider(id)).value ?? const [];
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.panel,
        border: Border(left: BorderSide(color: AppColors.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            height: 40,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: const BoxDecoration(
              color: AppColors.sidebar,
              border: Border(bottom: BorderSide(color: AppColors.line)),
            ),
            child: const Text(
              'INSPECTOR',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.faint,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: essay == null
                ? const SizedBox.shrink()
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
                    children: <Widget>[
                      _InspectorSection(
                        icon: Icons.description_outlined,
                        title: 'Details',
                        child: Column(
                          children: <Widget>[
                            _InspectorPair(
                              label: 'Status',
                              value: essay.status,
                              pill: true,
                            ),
                            const _InspectorPair(
                              label: 'Created',
                              value: 'Oct 24, 2023',
                            ),
                            _InspectorPair(
                              label: 'Word count',
                              value: '${essay.wordCount} words',
                            ),
                            _InspectorPair(
                              label: 'Version',
                              value: '${essay.versionNumber}',
                            ),
                          ],
                        ),
                      ),
                      _InspectorSection(
                        icon: Icons.sell_outlined,
                        title: 'Tags',
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: <Widget>[
                            for (final tag in [
                              ...essay.topics,
                              ...essay.areaTags,
                            ])
                              _TagPill(label: tag),
                            const _DashedPill(label: 'Add tag'),
                          ],
                        ),
                      ),
                      _InspectorSection(
                        icon: Icons.link,
                        title: 'Links',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Text(
                              'Backlinks',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.faint,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            for (final link in essay.links)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    const Icon(
                                      Icons.description_outlined,
                                      size: 15,
                                      color: AppColors.faint,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        link.name,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.muted,
                                          height: 1.35,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      _InspectorSection(
                        icon: Icons.history,
                        title: 'History',
                        child: Column(
                          children: <Widget>[
                            const _TimelineItem(
                              title: 'Auto-saved',
                              subtitle: 'Just now',
                              active: true,
                            ),
                            for (final snap in snaps.take(3))
                              _TimelineItem(
                                title: 'Version ${snap.versionNumber}',
                                subtitle: snap.changeSummary,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _InspectorSection extends StatelessWidget {
  const _InspectorSection({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 15, color: AppColors.faint),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _InspectorPair extends StatelessWidget {
  const _InspectorPair({
    required this.label,
    required this.value,
    this.pill = false,
  });

  final String label;
  final String value;
  final bool pill;

  @override
  Widget build(BuildContext context) {
    final valueWidget = pill
        ? DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.subtle,
              border: Border.all(color: AppColors.line),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          )
        : Text(
            value,
            style: const TextStyle(fontSize: 12, color: AppColors.text),
          );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const Spacer(),
          valueWidget,
        ],
      ),
    );
  }
}

class _TagPill extends StatelessWidget {
  const _TagPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.subtle,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.muted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _DashedPill extends StatelessWidget {
  const _DashedPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: const Color(0xffd4d4d8)),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.add, size: 13, color: AppColors.muted),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
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

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({
    required this.title,
    required this.subtitle,
    this.active = false,
  });

  final String title;
  final String subtitle;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Column(
            children: <Widget>[
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: active ? AppColors.muted : AppColors.line,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.panel, width: 2),
                ),
              ),
              Expanded(child: Container(width: 1, color: AppColors.line)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: active ? AppColors.text : AppColors.muted,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.faint,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopResultOverlay extends ConsumerWidget {
  const _DesktopResultOverlay({required this.workspace});

  final DesktopWorkspaceState workspace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = workspace.overlayResultIds
        .map((id) => ref.watch(essayByIdProvider(id)).value)
        .whereType<Essay>()
        .toList();
    return Positioned.fill(
      left: _sidebarWidth,
      child: Material(
        color: AppColors.panel.withValues(alpha: 0.96),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(48, 34, 48, 48),
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    workspace.overlayTitle ?? 'Results',
                    style: const TextStyle(
                      fontSize: 24,
                      height: 1.15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                ),
                Text(
                  '${rows.length} essays',
                  style: const TextStyle(fontSize: 14, color: AppColors.muted),
                ),
                const SizedBox(width: 16),
                IconButton(
                  onPressed: () =>
                      ref.read(desktopWorkspaceProvider.notifier).hideOverlay(),
                  icon: const Icon(Icons.close, color: AppColors.muted),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              children: <Widget>[
                _TagPill(label: workspace.overlayTitle ?? 'Results'),
                const _TagPill(label: 'Sort: recently updated'),
              ],
            ),
            const SizedBox(height: 18),
            const Divider(height: 1),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Pick a row to open it in an essay tab. Press Esc to close.',
                style: TextStyle(fontSize: 13, color: AppColors.muted),
              ),
            ),
            const Divider(height: 1),
            const SizedBox(height: 12),
            for (final essay in rows)
              _OverlayResultRow(
                essay: essay,
                onTap: () => ref
                    .read(desktopWorkspaceProvider.notifier)
                    .openEssay(essay.id, fromOverlay: true),
              ),
          ],
        ),
      ),
    );
  }
}

class _OverlayResultRow extends StatelessWidget {
  const _OverlayResultRow({required this.essay, required this.onTap});

  final Essay essay;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  StatusDot(status: essay.status),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      essay.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '${essay.status} · edited ${essay.updatedLabel}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                essay.excerpt,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: AppColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
