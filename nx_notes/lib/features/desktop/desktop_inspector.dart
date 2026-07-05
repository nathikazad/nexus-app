part of 'desktop_shell.dart';

enum _InspectorTab { contents, details }

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
        : ref.watch(documentByIdProvider(id)).value;
    final snaps = id == null
        ? const <DocumentSnap>[]
        : ref.watch(documentSnapshotsProvider(id)).value ?? const [];
    final tagSystems = ref.watch(tagSystemsProvider).value ?? const [];
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
                _InspectorTabButton(
                  label: 'Contents',
                  active: _tab == _InspectorTab.contents,
                  onTap: () => setState(() => _tab = _InspectorTab.contents),
                ),
                _InspectorTabButton(
                  label: 'Details',
                  active: _tab == _InspectorTab.details,
                  onTap: () => setState(() => _tab = _InspectorTab.details),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: document == null
                ? const SizedBox.shrink()
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

class _InspectorPinnedSwitch extends ConsumerStatefulWidget {
  const _InspectorPinnedSwitch({required this.document});

  final NxDocument document;

  @override
  ConsumerState<_InspectorPinnedSwitch> createState() =>
      _InspectorPinnedSwitchState();
}

class _InspectorPinnedSwitchState
    extends ConsumerState<_InspectorPinnedSwitch> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: <Widget>[
          Text(
            'Pinned',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const Spacer(),
          SizedBox(
            width: 42,
            height: 24,
            child: FittedBox(
              fit: BoxFit.contain,
              child: Switch.adaptive(
                value: widget.document.pinned,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                activeThumbColor: AppColors.text,
                onChanged: _saving ? null : _setPinned,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _setPinned(bool pinned) async {
    setState(() => _saving = true);
    try {
      await ref
          .read(documentMutationControllerProvider)
          .setPinned(widget.document, pinned);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not update pin: $error')));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}

class _InspectorActions extends ConsumerStatefulWidget {
  const _InspectorActions({required this.document});

  final NxDocument document;

  @override
  ConsumerState<_InspectorActions> createState() => _InspectorActionsState();
}

class _InspectorActionsState extends ConsumerState<_InspectorActions> {
  bool _saving = false;
  bool _publishing = false;
  bool _deleting = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        children: <Widget>[
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                alignment: Alignment.centerLeft,
                backgroundColor: AppColors.floating,
                foregroundColor: AppColors.onFloating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed: _saving || _deleting ? null : _saveNow,
              icon: _saving
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.onFloating,
                      ),
                    )
                  : const Icon(Icons.save_outlined, size: 16),
              label: Text(_saving ? 'Saving...' : 'Save now'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                alignment: Alignment.centerLeft,
                backgroundColor: widget.document.publish.enabled
                    ? AppColors.panel
                    : AppColors.floating,
                foregroundColor: widget.document.publish.enabled
                    ? AppColors.text
                    : AppColors.onFloating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed: _saving || _publishing || _deleting
                  ? null
                  : _togglePublish,
              icon: _publishing
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: widget.document.publish.enabled
                            ? AppColors.text
                            : AppColors.onFloating,
                      ),
                    )
                  : Icon(
                      widget.document.publish.enabled
                          ? Icons.public_off_outlined
                          : Icons.public_outlined,
                      size: 16,
                    ),
              label: Text(
                _publishing
                    ? 'Updating publish...'
                    : widget.document.publish.enabled
                    ? 'Unpublish'
                    : 'Publish',
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                alignment: Alignment.centerLeft,
                foregroundColor: AppColors.red,
                side: BorderSide(color: AppColors.red),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed: _saving || _deleting ? null : _confirmDelete,
              icon: _deleting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline, size: 16),
              label: Text(_deleting ? 'Deleting...' : 'Delete'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveNow() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(documentMutationControllerProvider)
          .saveNow(widget.document);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Document saved')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save document: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _togglePublish() async {
    final nextEnabled = !widget.document.publish.enabled;
    setState(() => _publishing = true);
    try {
      await ref
          .read(documentMutationControllerProvider)
          .setPublishEnabled(widget.document, nextEnabled);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nextEnabled
                ? 'Document published and synced'
                : 'Document unpublished and synced',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update publishing: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _publishing = false);
      }
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _DeleteDocumentDialog(title: widget.document.title),
    );
    if (confirmed != true || !mounted) return;
    await _deleteDocument();
  }

  Future<void> _deleteDocument() async {
    setState(() => _deleting = true);
    try {
      await ref
          .read(documentMutationControllerProvider)
          .deleteDocument(widget.document);
      ref.read(desktopWorkspaceProvider.notifier).closeTab(widget.document.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Document deleted')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete document: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _deleting = false);
      }
    }
  }
}

class _DeleteDocumentDialog extends StatelessWidget {
  const _DeleteDocumentDialog({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.panel,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppColors.line),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.delete_outline, size: 17, color: AppColors.red),
                  const SizedBox(width: 8),
                  Text(
                    'Delete document?',
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'This permanently removes the document and closes its open tab.',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: AppColors.sidebar,
                  border: Border.all(color: AppColors.line),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  title.trim().isEmpty ? 'Untitled document' : title.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: <Widget>[
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.muted,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(true),
                    icon: const Icon(Icons.delete_outline, size: 15),
                    label: const Text('Delete'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CollapsedInspector extends ConsumerWidget {
  const _CollapsedInspector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.sidebar,
        border: Border(left: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            const SizedBox(height: 6),
            IconButton(
              tooltip: 'Expand inspector',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 32, height: 32),
              onPressed: () =>
                  ref.read(desktopWorkspaceProvider.notifier).toggleInspector(),
              icon: Icon(Icons.chevron_left, size: 18, color: AppColors.faint),
            ),
            const SizedBox(height: 8),
            RotatedBox(
              quarterTurns: 1,
              child: Text(
                'INSPECTOR',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.faint,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ),
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
                style: TextStyle(
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
  const _InspectorPair({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: <Widget>[
          Text(label, style: TextStyle(fontSize: 12, color: AppColors.muted)),
          const Spacer(),
          Text(value, style: TextStyle(fontSize: 12, color: AppColors.text)),
        ],
      ),
    );
  }
}

class _InspectorStatusPair extends ConsumerWidget {
  const _InspectorStatusPair({required this.document, required this.statuses});

  final NxDocument document;
  final List<String> statuses;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final values = statuses.contains(document.status)
        ? statuses
        : <String>[document.status, ...statuses];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: <Widget>[
          Text(
            'Status',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const Spacer(),
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.subtle,
              border: Border.all(color: AppColors.line),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Padding(
              padding: const EdgeInsets.only(left: 8, right: 4),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: document.status,
                  isDense: true,
                  icon: Icon(
                    Icons.keyboard_arrow_down,
                    size: 15,
                    color: AppColors.muted,
                  ),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                  dropdownColor: AppColors.panel,
                  borderRadius: BorderRadius.circular(6),
                  items: [
                    for (final status in values)
                      DropdownMenuItem<String>(
                        value: status,
                        child: Text(status),
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null || value == document.status) return;
                    _saveDocumentMetadata(
                      ref,
                      document.copyWith(
                        status: value,
                        tagsBySystem: <String, List<String>>{
                          ...document.tagsBySystem,
                          'Status': <String>[value],
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
