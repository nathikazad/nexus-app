import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nx_projects/core/theme/app_theme.dart';
import 'package:nx_projects/core/theme/kind_color_palette.dart';
import 'package:nx_projects/data/providers.dart';
import 'package:nx_projects/domain/project/project.dart';
import 'package:nx_projects/domain/sprint/sprint.dart';
import 'package:nx_projects/domain/task/task.dart';
import 'package:nx_projects/domain/task/task_kind.dart';
import 'package:nx_projects/features/shell/selection_providers.dart';
import 'package:nx_projects/features/sprint/sprint_view_model.dart';

/// Which edge has the 1px separator toward the main content.
enum SprintCartBorder {
  /// Cart is on the right (Planner): border on the left of the cart.
  left,

  /// Cart is on the left (Sprint): border on the right of the cart.
  right,
}

/// `reference/desktop/partials/panel-sprint-cart.html` — sprint nav, dots, capacity, list, footer.
class SprintCart extends ConsumerWidget {
  const SprintCart({
    super.key,
    required this.border,
    required this.onGoToSprintView,
  });

  final SprintCartBorder border;
  final VoidCallback onGoToSprintView;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sprints = ref.watch(sprintsListProvider);
    final idx = ref.watch(sprintIndexProvider);
    final sp = idx >= 0 && idx < sprints.length ? sprints[idx] : sprints[1];
    final stats = ref.watch(sprintHeaderStatsProvider);
    final tasks = ref.watch(sprintTasksProvider);
    final projects = ref.watch(projectsListProvider);

    final box = BoxDecoration(
      color: AppColors.panel,
      border: border == SprintCartBorder.left
          ? const Border(left: BorderSide(color: AppColors.border))
          : const Border(right: BorderSide(color: AppColors.border)),
    );

    return Container(
      width: 340,
      decoration: box,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SprintNavStrip(
            sp: sp,
            sprintIdx: idx,
            sprints: sprints,
            onPrev: () {
              if (idx > 0) ref.read(sprintIndexProvider.notifier).set(idx - 1);
            },
            onNext: () {
              if (idx < sprints.length - 1) {
                ref.read(sprintIndexProvider.notifier).set(idx + 1);
              }
            },
          ),
          _SprintDots(
            sprints: sprints,
            currentIdx: idx,
            onPick: (i) => ref.read(sprintIndexProvider.notifier).set(i),
          ),
          _CapBlock(stats: stats, sprint: sp),
          Expanded(
            child: _CartBody(
              tasks: tasks,
              projects: projects,
            ),
          ),
          _CartFooter(onSprintView: onGoToSprintView),
        ],
      ),
    );
  }
}

class _SprintNavStrip extends StatelessWidget {
  const _SprintNavStrip({
    required this.sp,
    required this.sprintIdx,
    required this.sprints,
    required this.onPrev,
    required this.onNext,
  });

  final Sprint sp;
  final int sprintIdx;
  final List<Sprint> sprints;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final canPrev = sprintIdx > 0;
    final canNext = sprintIdx < sprints.length - 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 6),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          _Chev(label: '‹', enabled: canPrev, onTap: onPrev),
          Expanded(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      sp.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _Badge(label: sp.badge),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  sp.dates,
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ],
            ),
          ),
          _Chev(label: '›', enabled: canNext, onTap: onNext),
        ],
      ),
    );
  }
}

class _Chev extends StatelessWidget {
  const _Chev({required this.label, required this.enabled, required this.onTap});

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 32,
          height: 32,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16,
                color: enabled ? AppColors.muted : AppColors.dim,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SprintDots extends StatelessWidget {
  const _SprintDots({
    required this.sprints,
    required this.currentIdx,
    required this.onPick,
  });

  final List<Sprint> sprints;
  final int currentIdx;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < sprints.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: InkWell(
                onTap: () => onPick(i),
                customBorder: const CircleBorder(),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == currentIdx ? AppColors.accent : AppColors.border2,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(width: 4),
          Text(
            '+',
            style: TextStyle(fontSize: 10, color: AppColors.dim),
          ),
        ],
      ),
    );
  }
}

class _CapBlock extends StatelessWidget {
  const _CapBlock({required this.stats, required this.sprint});

  final SprintHeaderStats stats;
  final Sprint sprint;

  @override
  Widget build(BuildContext context) {
    final totalLabel = stats.totalH == stats.totalH.roundToDouble()
        ? '${stats.totalH.toInt()}'
        : stats.totalH.toStringAsFixed(1);
    final cap = sprint.capH;
    final pct = cap > 0 ? (stats.totalH / cap * 100).clamp(0, 100) : 0.0;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Capacity', style: TextStyle(fontSize: 12, color: AppColors.muted)),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${totalLabel}h',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                    TextSpan(
                      text: ' / ${cap.toInt()}h',
                      style: const TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 8,
              child: Stack(
                children: [
                  const ColoredBox(
                    color: AppColors.panel3,
                    child: SizedBox.expand(),
                  ),
                  FractionallySizedBox(
                    widthFactor: pct / 100,
                    child: const ColoredBox(color: AppColors.accent),
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

Project? _projectById(List<Project> projects, String id) {
  for (final p in projects) {
    if (p.id == id) return p;
  }
  return null;
}

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

class _CartBody extends StatelessWidget {
  const _CartBody({required this.tasks, required this.projects});

  final List<Task> tasks;
  final List<Project> projects;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No tasks in this sprint.',
            textAlign: TextAlign.center,
            style: TextStyle(
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
      children: [
        for (final k in keys) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 14, 6, 4),
            child: Text(
              k.toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                letterSpacing: 0.8,
                color: AppColors.dim,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          for (final t in groups[k]!) _CartTaskRow(task: t),
        ],
      ],
    );
  }
}

class _CartTaskRow extends StatelessWidget {
  const _CartTaskRow({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    final g = task.kind == TaskKind.feat ? '◉' : '●';
    final gColor = kindColor(task.kind);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(5),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            child: Row(
              children: [
                SizedBox(
                  width: 14,
                  child: Text(
                    g,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: gColor),
                  ),
                ),
                Expanded(
                  child: Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppColors.text),
                  ),
                ),
                SizedBox(
                  width: 40,
                  child: Text(
                    '${task.estimate % 1 == 0 ? task.estimate.toInt() : task.estimate}h',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CartFooter extends StatelessWidget {
  const _CartFooter({required this.onSprintView});

  final VoidCallback onSprintView;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Material(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onSprintView,
          borderRadius: BorderRadius.circular(6),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Center(
              child: Text(
                'Sprint View',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppColors.bg,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (label) {
      'active' => (AppColors.accent, AppColors.bg),
      'planned' => (const Color(0x2EC084FC), AppColors.pMobile),
      _ => (const Color(0x338A93A6), AppColors.muted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: fg,
        ),
      ),
    );
  }
}
