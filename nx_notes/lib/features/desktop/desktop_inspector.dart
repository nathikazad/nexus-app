part of 'desktop_shell.dart';

enum _InspectorTab { details, contents }

class _DesktopInspector extends ConsumerStatefulWidget {
  const _DesktopInspector({required this.essayId});

  final int? essayId;

  @override
  ConsumerState<_DesktopInspector> createState() => _DesktopInspectorState();
}

class _DesktopInspectorState extends ConsumerState<_DesktopInspector> {
  _InspectorTab _tab = _InspectorTab.details;

  @override
  Widget build(BuildContext context) {
    final id = widget.essayId;
    final essay = id == null ? null : ref.watch(essayByIdProvider(id)).value;
    final snaps = id == null
        ? const <EssaySnap>[]
        : ref.watch(essaySnapshotsProvider(id)).value ?? const [];
    final tagSystems = ref.watch(tagSystemsProvider).value ?? const [];
    final statusSystem = tagSystems.where((system) => system.name == 'Status');
    final editableTagSystems = tagSystems
        .where((system) => system.name != 'Status')
        .toList();
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
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: const BoxDecoration(
              color: AppColors.sidebar,
              border: Border(bottom: BorderSide(color: AppColors.line)),
            ),
            child: Row(
              children: <Widget>[
                const Text(
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
                  icon: const Icon(
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
                  label: 'Details',
                  active: _tab == _InspectorTab.details,
                  onTap: () => setState(() => _tab = _InspectorTab.details),
                ),
                _InspectorTabButton(
                  label: 'Contents',
                  active: _tab == _InspectorTab.contents,
                  onTap: () => setState(() => _tab = _InspectorTab.contents),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: essay == null
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
                              essay: essay,
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
                            _InspectorPinnedSwitch(essay: essay),
                          ],
                        ),
                      ),
                      _InspectorSection(
                        icon: Icons.sell_outlined,
                        title: 'Tags',
                        child: _InspectorTagsEditor(
                          essay: essay,
                          systems: editableTagSystems,
                        ),
                      ),
                      _InspectorSection(
                        icon: Icons.link,
                        title: 'Links',
                        child: _InspectorLinksEditor(essay: essay),
                      ),
                      _InspectorActions(essay: essay),
                      _InspectorSection(
                        icon: Icons.history,
                        title: 'History',
                        child: _InspectorHistory(essay: essay, snaps: snaps),
                      ),
                    ],
                  )
                : _InspectorContents(essay: essay),
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

class _InspectorContents extends StatelessWidget {
  const _InspectorContents({required this.essay});

  final Essay essay;

  @override
  Widget build(BuildContext context) {
    final headings = _headingsFromEssay(essay);
    return ValueListenableBuilder<EssayActiveHeading?>(
      valueListenable: essayActiveHeadingNotifier,
      builder: (context, activeHeading, _) {
        final activeBlockIndex = activeHeading?.essayId == essay.id
            ? activeHeading?.blockIndex
            : null;
        return ListView(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 32),
          children: <Widget>[
            if (headings.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(6, 6, 6, 0),
                child: Text(
                  'No headings',
                  style: TextStyle(fontSize: 12, color: AppColors.faint),
                ),
              )
            else
              for (final heading in headings)
                _InspectorHeadingRow(
                  heading: heading,
                  active: heading.blockIndex == activeBlockIndex,
                ),
          ],
        );
      },
    );
  }
}

class _InspectorHeadingRow extends StatelessWidget {
  const _InspectorHeadingRow({required this.heading, required this.active});

  final _EssayHeading heading;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final indent = (heading.level - 1).clamp(0, 4).toDouble() * 10.0;
    return Padding(
      padding: EdgeInsets.only(left: indent, bottom: 2),
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
    );
  }
}

class _EssayHeading {
  const _EssayHeading({
    required this.title,
    required this.level,
    required this.blockIndex,
  });

  final String title;
  final int level;
  final int blockIndex;
}

List<_EssayHeading> _headingsFromEssay(Essay essay) {
  final document = essay.jsonDocument['document'];
  final children = document is Map ? document['children'] : null;
  if (children is! List) return const <_EssayHeading>[];

  final headings = <_EssayHeading>[];
  for (var i = 0; i < children.length; i++) {
    final raw = children[i];
    if (raw is! Map || raw['type'] != 'heading') continue;
    final text = _nodeText(raw).trim();
    if (text.isEmpty) continue;
    headings.add(
      _EssayHeading(title: text, level: _headingLevel(raw), blockIndex: i),
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
  const _InspectorPinnedSwitch({required this.essay});

  final Essay essay;

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
          const Text(
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
                value: widget.essay.pinned,
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
          .read(essayMutationControllerProvider)
          .setPinned(widget.essay, pinned);
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
  const _InspectorActions({required this.essay});

  final Essay essay;

  @override
  ConsumerState<_InspectorActions> createState() => _InspectorActionsState();
}

class _InspectorActionsState extends ConsumerState<_InspectorActions> {
  bool _saving = false;
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
                backgroundColor: AppColors.text,
                foregroundColor: Colors.white,
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
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_outlined, size: 16),
              label: Text(_saving ? 'Saving...' : 'Save now'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                alignment: Alignment.centerLeft,
                foregroundColor: AppColors.red,
                side: const BorderSide(color: AppColors.red),
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
      await ref.read(essayMutationControllerProvider).saveNow(widget.essay);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Essay saved')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save essay: $error')));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete essay?'),
        content: Text('Delete "${widget.essay.title}" permanently?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _deleteEssay();
  }

  Future<void> _deleteEssay() async {
    setState(() => _deleting = true);
    try {
      await ref.read(essayMutationControllerProvider).deleteEssay(widget.essay);
      ref.read(desktopWorkspaceProvider.notifier).closeTab(widget.essay.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Essay deleted')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not delete essay: $error')));
    } finally {
      if (mounted) {
        setState(() => _deleting = false);
      }
    }
  }
}

class _CollapsedInspector extends ConsumerWidget {
  const _CollapsedInspector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DecoratedBox(
      decoration: const BoxDecoration(
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
              icon: const Icon(
                Icons.chevron_left,
                size: 18,
                color: AppColors.faint,
              ),
            ),
            const SizedBox(height: 8),
            const RotatedBox(
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
  const _InspectorPair({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontSize: 12, color: AppColors.text),
          ),
        ],
      ),
    );
  }
}

class _InspectorStatusPair extends ConsumerWidget {
  const _InspectorStatusPair({required this.essay, required this.statuses});

  final Essay essay;
  final List<String> statuses;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final values = statuses.contains(essay.status)
        ? statuses
        : <String>[essay.status, ...statuses];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: <Widget>[
          const Text(
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
                  value: essay.status,
                  isDense: true,
                  icon: const Icon(
                    Icons.keyboard_arrow_down,
                    size: 15,
                    color: AppColors.muted,
                  ),
                  style: const TextStyle(
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
                    if (value == null || value == essay.status) return;
                    _saveEssayMetadata(
                      ref,
                      essay.copyWith(
                        status: value,
                        tagsBySystem: <String, List<String>>{
                          ...essay.tagsBySystem,
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
