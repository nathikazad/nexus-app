import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icon_pack/solar_icon_pack.dart';

import 'package:nx_time/core/theme/app_theme.dart';
import 'package:nx_time/features/tasks/project_drill_page.dart';
import 'package:nx_time/features/tasks/projects_browse_view_model.dart';

/// Reference: `reference/partials/page-projects-browse.html`
class ProjectsBrowsePage extends ConsumerStatefulWidget {
  const ProjectsBrowsePage({
    super.key,
    this.mode = ProjectsBrowseMode.browse,
  });

  final ProjectsBrowseMode mode;

  @override
  ConsumerState<ProjectsBrowsePage> createState() => _ProjectsBrowsePageState();
}

class _ProjectsBrowsePageState extends ConsumerState<ProjectsBrowsePage> {
  final Set<int> _accumulatedTaskIds = {};

  @override
  Widget build(BuildContext context) {
    final rowsAsync = ref.watch(projectBrowseRowsProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(SolarLinearIcons.arrowLeft, size: 22),
                    color: AppColors.slate600,
                  ),
                  Expanded(
                    child: Text(
                      widget.mode == ProjectsBrowseMode.pickProject
                          ? 'Pick project'
                          : widget.mode == ProjectsBrowseMode.pickTask
                              ? 'Pick tasks (projects)'
                              : 'Projects',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                        color: AppColors.slate900,
                      ),
                    ),
                  ),
                  if (widget.mode == ProjectsBrowseMode.pickTask)
                    TextButton(
                      onPressed: () => Navigator.of(context)
                          .pop<Set<int>>(Set<int>.from(_accumulatedTaskIds)),
                      child: const Text('Done'),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.slate200),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(SolarLinearIcons.magnifer, size: 18, color: AppColors.slate400),
                    const SizedBox(width: 8),
                    Text(
                      'Search projects…',
                      style: TextStyle(fontSize: 14, color: AppColors.slate400),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: rowsAsync.when(
                data: (rows) {
                  return ListView.separated(
                    itemCount: rows.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: AppColors.slate100),
                    itemBuilder: (context, i) {
                      final r = rows[i];
                      return Material(
                        color: Colors.white,
                        child: InkWell(
                          onTap: () async {
                            if (widget.mode == ProjectsBrowseMode.pickProject) {
                              if (r.subProjectCount > 0) {
                                final picked = await Navigator.of(context)
                                    .push<int?>(
                                  MaterialPageRoute(
                                    builder: (_) => ProjectDrillPage(
                                      projectId: r.project.id,
                                      mode: ProjectsBrowseMode.pickProject,
                                    ),
                                  ),
                                );
                                if (!context.mounted) return;
                                if (picked != null) {
                                  Navigator.of(context).pop<int>(picked);
                                }
                              } else {
                                Navigator.of(context).pop<int>(r.project.id);
                              }
                              return;
                            }
                            final result = await Navigator.of(context)
                                .push<Set<int>?>(
                              MaterialPageRoute(
                                builder: (_) => ProjectDrillPage(
                                  projectId: r.project.id,
                                  mode: widget.mode,
                                ),
                              ),
                            );
                            if (!mounted) return;
                            if (widget.mode == ProjectsBrowseMode.pickTask &&
                                result != null) {
                              setState(() => _accumulatedTaskIds.addAll(result));
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        r.project.name,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.slate900,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        r.subtitle,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.slate500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  SolarLinearIcons.altArrowRight,
                                  size: 18,
                                  color: AppColors.slate400,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('$e')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
