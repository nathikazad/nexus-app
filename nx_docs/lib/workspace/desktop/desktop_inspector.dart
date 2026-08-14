part of 'desktop_workspace.dart';

enum _InspectorTab { contents, details, ai }

class _DesktopInspector extends ConsumerStatefulWidget {
  const _DesktopInspector({required this.documentId});

  final int? documentId;

  @override
  ConsumerState<_DesktopInspector> createState() => _DesktopInspectorState();
}

class _DesktopInspectorState extends ConsumerState<_DesktopInspector> {
  _InspectorTab _tab = _InspectorTab.contents;

  @override
  Widget build(BuildContext context) {
    final id = widget.documentId;
    final document = id == null
        ? null
        : ref.watch(offlineDocumentProvider(id)).value;
    final snaps = id == null
        ? const <DocumentSnap>[]
        : ref.watch(documentSnapshotsProvider(id)).value ?? const [];
    final tagSystems =
        ref.watch(offlineTagSystemsProvider).value ?? const <TagSystem>[];
    final statusSystem = tagSystems.where((system) => system.name == 'Status');
    final editableTagSystems = tagSystems
        .where((system) => system.name != 'Status')
        .toList();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border(left: BorderSide(color: AppColors.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: AppColors.sidebar,
              border: Border(bottom: BorderSide(color: AppColors.line)),
            ),
            child: Row(
              children: <Widget>[
                Text(
                  'INSPECTOR',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.faint,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Collapse inspector',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 28,
                    height: 28,
                  ),
                  onPressed: () => ref
                      .read(desktopWorkspaceProvider.notifier)
                      .toggleInspector(),
                  icon: Icon(
                    Icons.chevron_right,
                    size: 17,
                    color: AppColors.faint,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: _InspectorTabButton(
                    label: 'Contents',
                    active: _tab == _InspectorTab.contents,
                    onTap: () => setState(() => _tab = _InspectorTab.contents),
                  ),
                ),
                Expanded(
                  child: _InspectorTabButton(
                    label: 'Details',
                    active: _tab == _InspectorTab.details,
                    onTap: () => setState(() => _tab = _InspectorTab.details),
                  ),
                ),
                Expanded(
                  child: _InspectorTabButton(
                    label: 'AI',
                    active: _tab == _InspectorTab.ai,
                    onTap: () => setState(() => _tab = _InspectorTab.ai),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: document == null
                ? const SizedBox.shrink()
                : _tab == _InspectorTab.ai
                ? NoteCompanion(
                    key: ValueKey<int>(document.id),
                    document: document,
                    embeddedChat: true,
                    voiceEnabled: false,
                  )
                : _tab == _InspectorTab.details
                ? ListView(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
                    children: <Widget>[
                      _InspectorSection(
                        icon: Icons.description_outlined,
                        title: 'Details',
                        child: Column(
                          children: <Widget>[
                            _InspectorStatusPair(
                              document: document,
                              statuses: statusSystem.isEmpty
                                  ? const <String>[
                                      'Draft',
                                      'In Progress',
                                      'Published',
                                      'Discarded',
                                    ]
                                  : statusSystem.first.nodes
                                        .map((node) => node.name)
                                        .toList(),
                            ),
                            _InspectorPair(
                              label: 'Model ID',
                              value: '${document.id}',
                            ),
                            const _InspectorPair(
                              label: 'Created',
                              value: 'Oct 24, 2023',
                            ),
                            _InspectorPair(
                              label: 'Word count',
                              value: '${document.wordCount} words',
                            ),
                            _InspectorPair(
                              label: 'Version',
                              value: '${document.versionNumber}',
                            ),
                            _InspectorPinnedSwitch(document: document),
                          ],
                        ),
                      ),
                      _InspectorSection(
                        icon: Icons.sell_outlined,
                        title: 'Tags',
                        child: _InspectorTagsEditor(
                          document: document,
                          systems: editableTagSystems,
                        ),
                      ),
                      _InspectorSection(
                        icon: Icons.link,
                        title: 'Links',
                        child: _InspectorLinksEditor(document: document),
                      ),
                      _InspectorActions(document: document),
                      _InspectorSection(
                        icon: Icons.history,
                        title: 'History',
                        child: _InspectorHistory(
                          document: document,
                          snaps: snaps,
                        ),
                      ),
                    ],
                  )
                : _InspectorContents(document: document),
          ),
        ],
      ),
    );
  }
}

class _InspectorTabButton extends StatelessWidget {
  const _InspectorTabButton({
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
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: active
            ? BoxDecoration(
                color: AppColors.panel,
                border: Border(
                  top: BorderSide(color: AppColors.line),
                  left: BorderSide(color: AppColors.line),
                  right: BorderSide(color: AppColors.line),
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
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

class _InspectorContents extends StatefulWidget {
  const _InspectorContents({required this.document});

  final NxDocument document;

  @override
  State<_InspectorContents> createState() => _InspectorContentsState();
}

class _InspectorContentsState extends State<_InspectorContents> {
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _headingKeys = <int, GlobalKey>{};
  int? _lastEnsuredBlockIndex;

  @override
  void didUpdateWidget(covariant _InspectorContents oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.document.id != widget.document.id) {
      _headingKeys.clear();
      _lastEnsuredBlockIndex = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final headings = _headingsFromDocument(widget.document);
    _syncHeadingKeys(headings);
    return ValueListenableBuilder<DocumentActiveHeading?>(
      valueListenable: documentActiveHeadingNotifier,
      builder: (context, activeHeading, _) {
        final activeBlockIndex = activeHeading?.documentId == widget.document.id
            ? activeHeading?.blockIndex
            : null;
        _scheduleActiveHeadingVisibility(activeBlockIndex);
        return SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (headings.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
                  child: Text(
                    'No headings',
                    style: TextStyle(fontSize: 12, color: AppColors.faint),
                  ),
                )
              else
                for (final heading in headings)
                  _InspectorHeadingRow(
                    key: _headingKeys[heading.blockIndex],
                    heading: heading,
                    active: heading.blockIndex == activeBlockIndex,
                    onTap: () => requestDocumentHeadingScroll(
                      documentId: widget.document.id,
                      blockIndex: heading.blockIndex,
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }

  void _syncHeadingKeys(List<_DocumentHeading> headings) {
    final blockIndexes = headings.map((heading) => heading.blockIndex).toSet();
    _headingKeys.removeWhere(
      (blockIndex, _) => !blockIndexes.contains(blockIndex),
    );
    for (final heading in headings) {
      _headingKeys.putIfAbsent(heading.blockIndex, GlobalKey.new);
    }
  }

  void _scheduleActiveHeadingVisibility(int? activeBlockIndex) {
    if (activeBlockIndex == null ||
        activeBlockIndex == _lastEnsuredBlockIndex) {
      return;
    }
    _lastEnsuredBlockIndex = activeBlockIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final context = _headingKeys[activeBlockIndex]?.currentContext;
      if (context == null) return;
      Scrollable.ensureVisible(
        context,
        alignment: 0.45,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
      );
    });
  }
}

class _InspectorHeadingRow extends StatelessWidget {
  const _InspectorHeadingRow({
    required this.heading,
    required this.active,
    required this.onTap,
    super.key,
  });

  final _DocumentHeading heading;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final indent = (heading.level - 1).clamp(0, 4).toDouble() * 10.0;
    return Padding(
      padding: EdgeInsets.only(left: indent, bottom: 2),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: active ? AppColors.subtle : Colors.transparent,
              borderRadius: BorderRadius.circular(5),
              border: active ? Border.all(color: AppColors.line) : null,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              child: Text(
                heading.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: heading.level == 1 ? 12.5 : 12,
                  color: active ? AppColors.text : AppColors.muted,
                  fontWeight: active || heading.level <= 2
                      ? FontWeight.w700
                      : FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DocumentHeading {
  const _DocumentHeading({
    required this.title,
    required this.level,
    required this.blockIndex,
  });

  final String title;
  final int level;
  final int blockIndex;
}

List<_DocumentHeading> _headingsFromDocument(NxDocument nxDocument) {
  final documentJson = nxDocument.jsonDocument['document'];
  final children = documentJson is Map ? documentJson['children'] : null;
  if (children is! List) return const <_DocumentHeading>[];

  final headings = <_DocumentHeading>[];
  for (var i = 0; i < children.length; i++) {
    final raw = children[i];
    if (raw is! Map || raw['type'] != 'heading') continue;
    final text = _nodeText(raw).trim();
    if (text.isEmpty) continue;
    headings.add(
      _DocumentHeading(title: text, level: _headingLevel(raw), blockIndex: i),
    );
  }
  return headings;
}

int _headingLevel(Map<dynamic, dynamic> node) {
  final data = node['data'];
  final value = data is Map ? data['level'] : node['level'];
  if (value is int) return value.clamp(1, 6).toInt();
  if (value is num) return value.toInt().clamp(1, 6);
  return 1;
}

String _nodeText(Map<dynamic, dynamic> node) {
  final data = node['data'];
  final rawDelta = data is Map ? data['delta'] : node['delta'];
  if (rawDelta is! List) return '';
  final buffer = StringBuffer();
  for (final op in rawDelta) {
    if (op is Map && op['insert'] is String) {
      buffer.write(op['insert']);
    }
  }
  return buffer.toString();
}
