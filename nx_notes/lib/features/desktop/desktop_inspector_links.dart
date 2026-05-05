part of 'desktop_shell.dart';

class _InspectorLinksEditor extends ConsumerWidget {
  const _InspectorLinksEditor({required this.essay});

  final Essay essay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectLinks = essay.links
        .where((link) => link.modelType == 'Project')
        .toList();
    final otherLinks = essay.links
        .where((link) => link.modelType != 'Project')
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Project',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.faint,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: <Widget>[
            for (final project in projectLinks)
              _TagPill(
                label: project.name,
                onRemove: project.relationId == null
                    ? null
                    : () => _detachProject(ref, essay.id, project.relationId!),
              ),
            _AddProjectMenu(essay: essay, selectedProjects: projectLinks),
          ],
        ),
        const SizedBox(height: 18),
        const Text(
          'Other links',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.faint,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        if (otherLinks.isEmpty)
          const Text(
            'No other links',
            style: TextStyle(fontSize: 12, color: AppColors.faint),
          )
        else
          for (final link in otherLinks)
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
    );
  }
}

class _AddProjectMenu extends ConsumerWidget {
  const _AddProjectMenu({required this.essay, required this.selectedProjects});

  final Essay essay;
  final List<LinkedModel> selectedProjects;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectsProvider).value ?? const <LinkedModel>[];
    final selectedIds = selectedProjects.map((project) => project.id).toSet();
    final available = projects
        .where((project) => !selectedIds.contains(project.id))
        .toList();
    return PopupMenuButton<int>(
      tooltip: 'Attach project',
      enabled: available.isNotEmpty,
      color: AppColors.panel,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      onSelected: (projectId) => _attachProject(ref, essay.id, projectId),
      itemBuilder: (context) => [
        for (final project in available)
          PopupMenuItem<int>(
            value: project.id,
            height: 34,
            child: Text(
              project.name,
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
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

Future<void> _attachProject(WidgetRef ref, int essayId, int projectId) async {
  await ref
      .read(essayMutationControllerProvider)
      .attachProject(essayId, projectId);
}

Future<void> _detachProject(WidgetRef ref, int essayId, int relationId) async {
  await ref
      .read(essayMutationControllerProvider)
      .detachProject(essayId, relationId);
}
