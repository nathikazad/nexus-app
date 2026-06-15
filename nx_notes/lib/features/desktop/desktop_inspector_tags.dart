part of 'desktop_shell.dart';

class _InspectorTagsEditor extends ConsumerWidget {
  const _InspectorTagsEditor({required this.essay, required this.systems});

  final Essay essay;
  final List<TagSystem> systems;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (systems.isEmpty) {
      return const Text(
        'No editable tag systems',
        style: TextStyle(fontSize: 12, color: AppColors.faint),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final system in systems) ...<Widget>[
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Text(
              system.name,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.faint,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              for (final tag in _tagsForSystem(essay, system.name))
                _TagPill(
                  label: tag,
                  onRemove: () => _saveEssayMetadata(
                    ref,
                    _essayWithTagSystem(
                      essay,
                      system.name,
                      _tagsForSystem(
                        essay,
                        system.name,
                      ).where((item) => item != tag).toList(),
                    ),
                  ),
                ),
              _AddTagMenu(
                system: system,
                selected: _tagsForSystem(essay, system.name),
                onSelected: (tag) {
                  final current = _tagsForSystem(essay, system.name);
                  final next = system.exclusive
                      ? <String>[tag]
                      : <String>{...current, tag}.toList();
                  _saveEssayMetadata(
                    ref,
                    _essayWithTagSystem(essay, system.name, next),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _TagPill extends StatelessWidget {
  const _TagPill({required this.label, this.onRemove});

  final String label;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.subtle,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (onRemove != null) ...<Widget>[
              const SizedBox(width: 3),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onRemove,
                child: const SizedBox(
                  width: 17,
                  height: 17,
                  child: Icon(Icons.close, size: 13, color: AppColors.faint),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AddTagMenu extends StatelessWidget {
  const _AddTagMenu({
    required this.system,
    required this.selected,
    required this.onSelected,
  });

  final TagSystem system;
  final List<String> selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final nodes = _flattenTagNodes(system.nodes);
    final available = system.exclusive
        ? nodes
        : nodes.where((tag) => !selected.contains(tag)).toList();
    return PopupMenuButton<String>(
      tooltip: 'Add ${system.name} tag',
      enabled: available.isNotEmpty,
      color: AppColors.panel,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final tag in available)
          PopupMenuItem<String>(
            value: tag,
            height: 34,
            child: Text(tag, style: const TextStyle(fontSize: 13)),
          ),
      ],
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.panel,
          border: Border.all(color: const Color(0xffd4d4d8)),
          borderRadius: BorderRadius.circular(5),
        ),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Icon(Icons.add, size: 14, color: AppColors.muted),
        ),
      ),
    );
  }
}

List<String> _tagsForSystem(Essay essay, String system) {
  return switch (system) {
    'Status' => <String>[essay.status],
    'Topic' => essay.topics,
    'Area' => essay.areaTags,
    _ => essay.tagsBySystem[system] ?? const <String>[],
  };
}

Essay _essayWithTagSystem(Essay essay, String system, List<String> tags) {
  final nextTags = <String, List<String>>{...essay.tagsBySystem, system: tags};
  return essay.copyWith(
    topics: system == 'Topic' ? tags : null,
    areaTags: system == 'Area' ? tags : null,
    tagsBySystem: nextTags,
  );
}

List<String> _flattenTagNodes(List<TagNode> nodes) {
  final tags = <String>[];
  void visit(TagNode node) {
    tags.add(node.name);
    for (final child in node.children) {
      visit(child);
    }
  }

  for (final node in nodes) {
    visit(node);
  }
  return tags;
}

Future<void> _saveEssayMetadata(WidgetRef ref, Essay essay) async {
  await ref
      .read(essayMutationControllerProvider)
      .saveDraft(essay, policy: DraftSavePolicy.immediate);
}
