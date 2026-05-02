part of '../sprint_cart.dart';

String _projectLabelForTask(Task t, List<Project> projects) {
  final pid = t.projectId;
  if (pid == null) return 'Unassigned';
  final p = _projectById(projects, pid);
  if (p == null) return 'Unknown';
  if (t.subProjectId != null) {
    final sp = _projectById(projects, t.subProjectId!);
    if (sp != null) {
      return '${p.name} / ${sp.name}';
    }
  }
  return p.name;
}

String _topProjectForBreakdown(Task t) {
  final c = t.crumb.trim();
  if (c.isEmpty || c == '—' || c == '-') return 'Other';
  final first = c.split('/').first.trim();
  return first.isEmpty ? 'Other' : first;
}

Color _breakdownBarColor(String topProject) {
  switch (topProject) {
    case 'Nexus':
      return AppColors.pNexus;
    case 'Pipeline':
      return AppColors.pPipe;
    case 'Mobile App':
      return AppColors.pMobile;
    default:
      return AppColors.accent;
  }
}

String _cartGlyph(Task t) {
  switch (t.kind) {
    case TaskKind.bug:
      return '●';
    case TaskKind.feat:
      return '◉';
    case TaskKind.task:
      return '▢';
  }
}

class _CartSectionLabel extends StatelessWidget {
  const _CartSectionLabel(this.text, {this.topPadding = 14});
  final String text;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(4, topPadding, 4, 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          letterSpacing: 0.8,
          color: AppColors.dim,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _CartBody extends ConsumerWidget {
  const _CartBody({
    required this.sprint,
    required this.tasks,
    required this.projects,
    required this.surface,
  });

  final Sprint sprint;
  final List<Task> tasks;
  final List<Project> projects;
  final SprintCartSurface surface;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (tasks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No items in ${sprint.name} yet.\nClick ☆ on a backlog row to add.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.dim,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }
    final groups = <String, List<Task>>{};
    for (final t in tasks) {
      final k = _projectLabelForTask(t, projects);
      groups.putIfAbsent(k, () => []).add(t);
    }
    final keys = groups.keys.toList()..sort();
    final totalEst = tasks.fold<double>(0, (a, t) => a + t.estimate);
    final breakdown = <String, double>{};
    for (final t in tasks) {
      final p = _topProjectForBreakdown(t);
      breakdown[p] = (breakdown[p] ?? 0) + t.estimate;
    }
    final breakdownKeys = breakdown.keys.toList()..sort();
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
      children: [
        _CartSectionLabel('Items (${tasks.length})', topPadding: 4),
        for (final k in keys) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, 6, 4),
            child: Text(
              k,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.muted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          for (final t in groups[k]!)
            _CartTaskRow(
              task: t,
              surface: surface,
              onUnpin: () async {
                final cur =
                    await ref.read(taskRepositoryProvider).getById(t.id) ?? t;
                await ref
                    .read(taskRepositoryProvider)
                    .upsert(cur.copyWith(clearSprint: true));
                ref.invalidate(tasksListAsyncProvider);
              },
            ),
        ],
        const _CartSectionLabel('Breakdown'),
        _CartBreakdown(
          totalEst: totalEst,
          byProject: breakdown,
          projectKeys: breakdownKeys,
        ),
        const _CartSectionLabel('Sprint goal'),
        _SprintGoalField(key: ValueKey(sprint.id), sprint: sprint),
      ],
    );
  }
}

class _CartBreakdown extends StatelessWidget {
  const _CartBreakdown({
    required this.totalEst,
    required this.byProject,
    required this.projectKeys,
  });

  final double totalEst;
  final Map<String, double> byProject;
  final List<String> projectKeys;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 8),
      child: Column(
        children: [
          for (var i = 0; i < projectKeys.length; i++) ...[
            _BreakdownRow(
              name: projectKeys[i],
              hours: byProject[projectKeys[i]]!,
              total: totalEst,
              barColor: _breakdownBarColor(projectKeys[i]),
            ),
            if (i < projectKeys.length - 1) const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.name,
    required this.hours,
    required this.total,
    required this.barColor,
  });

  final String name;
  final double hours;
  final double total;
  final Color barColor;

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? ((hours / total) * 100).round() : 0;
    final hStr = hours == hours.roundToDouble()
        ? hours.toInt().toString()
        : hours.toStringAsFixed(1);
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: AppColors.muted),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth * (pct / 100).clamp(0.0, 1.0);
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    height: 5,
                    width: constraints.maxWidth,
                    decoration: BoxDecoration(
                      color: AppColors.panel3,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  Container(
                    height: 5,
                    width: w,
                    decoration: BoxDecoration(
                      color: barColor,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        SizedBox(
          width: 60,
          child: Text(
            '${hStr}h · $pct%',
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 11, color: AppColors.muted),
          ),
        ),
      ],
    );
  }
}
