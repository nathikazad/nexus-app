part of 'desktop_shell.dart';

class _InspectorLinksEditor extends ConsumerWidget {
  const _InspectorLinksEditor({required this.document});

  final NxDocument document;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectLinks = document.links
        .where((link) => link.modelType == 'Project')
        .toList();
    final otherLinks = document.links
        .where((link) => link.modelType != 'Project')
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
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
                    : () =>
                          _detachProject(ref, document.id, project.relationId!),
              ),
            _AddProjectMenu(document: document, selectedProjects: projectLinks),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          'Other links',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.faint,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        if (otherLinks.isEmpty)
          Text(
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
                  Icon(
                    Icons.description_outlined,
                    size: 15,
                    color: AppColors.faint,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      link.name,
                      style: TextStyle(
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
  const _AddProjectMenu({
    required this.document,
    required this.selectedProjects,
  });

  final NxDocument document;
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
      onSelected: (projectId) => _attachProject(ref, document.id, projectId),
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
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Icon(Icons.add, size: 14, color: AppColors.muted),
        ),
      ),
    );
  }
}

Future<void> _attachProject(
  WidgetRef ref,
  int documentId,
  int projectId,
) async {
  await ref
      .read(documentMutationControllerProvider)
      .attachProject(documentId, projectId);
}

Future<void> _detachProject(
  WidgetRef ref,
  int documentId,
  int relationId,
) async {
  await ref
      .read(documentMutationControllerProvider)
      .detachProject(documentId, relationId);
}
