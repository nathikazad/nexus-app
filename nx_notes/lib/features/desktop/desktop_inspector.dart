part of 'desktop_shell.dart';

class _DesktopInspector extends ConsumerWidget {
  const _DesktopInspector({required this.essayId});

  final int? essayId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = essayId;
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
                  tooltip: 'Log out',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 28,
                    height: 28,
                  ),
                  onPressed: () async {
                    await ref.read(authProvider.notifier).logout();
                    if (context.mounted) context.go('/login');
                  },
                  icon: const Icon(
                    Icons.logout,
                    size: 17,
                    color: AppColors.faint,
                  ),
                ),
              ],
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
                      _InspectorSection(
                        icon: Icons.history,
                        title: 'History',
                        child: _InspectorHistory(essay: essay, snaps: snaps),
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
