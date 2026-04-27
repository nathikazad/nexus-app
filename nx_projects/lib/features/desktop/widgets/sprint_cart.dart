import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:intl/intl.dart';

import 'package:nx_projects/core/formatting/date_label.dart';
import 'package:nx_projects/core/theme/app_theme.dart';
import 'package:nx_projects/core/theme/kind_color_palette.dart';
import 'package:nx_projects/data/providers.dart';
import 'package:nx_projects/domain/project/project.dart';
import 'package:nx_projects/domain/sprint/sprint.dart';
import 'package:nx_projects/domain/task/task.dart';
import 'package:nx_projects/domain/task/task_kind.dart';
import 'package:nx_projects/features/desktop/desktop_task_drawer_state.dart';
import 'package:nx_projects/features/shell/selection_providers.dart';
import 'package:nx_projects/features/sprint/sprint_view_model.dart';

/// Which edge has the 1px separator toward the main content.
enum SprintCartBorder {
  /// Cart is on the right (Planner): border on the left of the cart.
  left,

  /// Cart is on the left (Sprint): border on the right of the cart.
  right,
}

/// Whether the cart is shown beside Planner (backlog) or beside Sprint (day plan).
enum SprintCartSurface {
  /// Unpin (×) on each row; no unscheduled day indicator; footer → Sprint.
  planner,

  /// Unscheduled day indicator in the trailing column instead of ×; footer → Planner.
  sprint,
}

/// `reference/desktop/partials/panel-sprint-cart.html` — sprint nav, dots, capacity, list, footer.
class SprintCart extends ConsumerWidget {
  const SprintCart({
    super.key,
    required this.border,
    required this.surface,
    required this.onFooter,
  });

  final SprintCartBorder border;
  final SprintCartSurface surface;
  final VoidCallback onFooter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sprints = ref.watch(sprintsListProvider);
    final idx = ref.watch(sprintIndexProvider);
    if (sprints.isEmpty) {
      return const SizedBox.shrink();
    }
    final sp = idx >= 0 && idx < sprints.length
        ? sprints[idx]
        : sprints[sprints.length > 1 ? 1 : 0];
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
            onAdd: () =>
                ref.read(desktopTaskDrawerProvider.notifier).newSprint(),
          ),
          _CapBlock(stats: stats, sprint: sp),
          Expanded(
            child: _CartBody(
              sprint: sp,
              tasks: tasks,
              projects: projects,
              surface: surface,
            ),
          ),
          _CartFooter(surface: surface, onPressed: onFooter),
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
  const _Chev({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

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
    required this.onAdd,
  });

  final List<Sprint> sprints;
  final int currentIdx;
  final ValueChanged<int> onPick;
  final VoidCallback onAdd;

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
                    color: i == currentIdx
                        ? AppColors.accent
                        : AppColors.border2,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(width: 4),
          _SprintAddPlus(onTap: onAdd),
        ],
      ),
    );
  }
}

class _SprintAddPlus extends StatefulWidget {
  const _SprintAddPlus({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_SprintAddPlus> createState() => _SprintAddPlusState();
}

class _SprintAddPlusState extends State<_SprintAddPlus> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: InkWell(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            '+',
            style: TextStyle(
              fontSize: 10,
              color: _hover ? AppColors.text : AppColors.dim,
            ),
          ),
        ),
      ),
    );
  }
}

class _CapBlock extends ConsumerStatefulWidget {
  const _CapBlock({required this.stats, required this.sprint});

  final SprintHeaderStats stats;
  final Sprint sprint;

  @override
  ConsumerState<_CapBlock> createState() => _CapBlockState();
}

class _CapBlockState extends ConsumerState<_CapBlock> {
  late final TextEditingController _capController;
  late final FocusNode _capFocus;
  bool _editing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _capController = TextEditingController(
      text: _formatHours(widget.sprint.capH),
    );
    _capFocus = FocusNode();
    _capFocus.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (_capFocus.hasFocus || !_editing) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_capFocus.hasFocus || !_editing) return;
      _saveCapacity();
    });
  }

  @override
  void didUpdateWidget(covariant _CapBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editing &&
        (oldWidget.sprint.id != widget.sprint.id ||
            oldWidget.sprint.capH != widget.sprint.capH)) {
      _capController.text = _formatHours(widget.sprint.capH);
    }
  }

  @override
  void dispose() {
    _capFocus.removeListener(_onFocusChange);
    _capFocus.dispose();
    _capController.dispose();
    super.dispose();
  }

  String _formatHours(double v) {
    return v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
  }

  void _beginEdit() {
    if (_editing) return;
    setState(() {
      _editing = true;
      _capController.text = _formatHours(widget.sprint.capH);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _capFocus.requestFocus();
      _capController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _capController.text.length,
      );
    });
  }

  Future<void> _saveCapacity() async {
    if (_saving) return;
    final parsed = double.tryParse(_capController.text.trim());
    if (parsed == null || parsed < 0) {
      setState(() {
        _editing = false;
        _capController.text = _formatHours(widget.sprint.capH);
      });
      return;
    }

    if (parsed == widget.sprint.capH) {
      setState(() => _editing = false);
      return;
    }

    setState(() => _saving = true);
    try {
      await ref
          .read(sprintRepositoryProvider)
          .update(widget.sprint.copyWith(capH: parsed));
      ref.invalidate(sprintsListAsyncProvider);
      if (mounted) {
        setState(() {
          _editing = false;
          _capController.text = _formatHours(parsed);
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalLabel =
        widget.stats.totalH == widget.stats.totalH.roundToDouble()
        ? '${widget.stats.totalH.toInt()}'
        : widget.stats.totalH.toStringAsFixed(1);
    final cap = widget.sprint.capH;
    double fillRatio = 0.0;
    if (cap > 0 && widget.stats.totalH.isFinite) {
      final raw = widget.stats.totalH / cap;
      if (raw.isFinite) {
        fillRatio = raw.clamp(0.0, 1.0).toDouble();
      }
    }
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
              InkWell(
                onTap: _beginEdit,
                borderRadius: BorderRadius.circular(4),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                  child: Text(
                    'Capacity',
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ),
              ),
              _editing
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${totalLabel}h / ',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                          ),
                        ),
                        SizedBox(
                          width: 48,
                          height: 24,
                          child: TextField(
                            controller: _capController,
                            focusNode: _capFocus,
                            enabled: !_saving,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            onSubmitted: (_) => _saveCapacity(),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.text,
                            ),
                            cursorColor: AppColors.accent,
                            decoration: InputDecoration(
                              isDense: true,
                              filled: true,
                              fillColor: AppColors.panel2,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 5,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(5),
                                borderSide: const BorderSide(
                                  color: AppColors.border,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(5),
                                borderSide: const BorderSide(
                                  color: AppColors.border,
                                ),
                              ),
                              focusedBorder: const OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(5),
                                ),
                                borderSide: BorderSide(color: AppColors.accent),
                              ),
                            ),
                          ),
                        ),
                        const Text(
                          'h',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    )
                  : InkWell(
                      onTap: _beginEdit,
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 2,
                          vertical: 1,
                        ),
                        child: Text.rich(
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
                                text: ' / ${_formatHours(cap)}h',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 8,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final maxW = constraints.maxWidth.isFinite
                      ? constraints.maxWidth
                      : 0.0;
                  final fillW = (maxW * fillRatio).clamp(0.0, maxW).toDouble();
                  return Stack(
                    children: [
                      const Positioned.fill(
                        child: ColoredBox(color: AppColors.panel3),
                      ),
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: fillW,
                        child: const ColoredBox(color: AppColors.accent),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Project? _projectById(List<Project> projects, int id) {
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
              onTap: surface == SprintCartSurface.sprint
                  ? () => ref
                      .read(desktopTaskDrawerProvider.notifier)
                      .viewTask(t.id)
                  : null,
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

class _SprintGoalField extends ConsumerStatefulWidget {
  const _SprintGoalField({super.key, required this.sprint});

  final Sprint sprint;

  @override
  ConsumerState<_SprintGoalField> createState() => _SprintGoalFieldState();
}

class _SprintGoalFieldState extends ConsumerState<_SprintGoalField> {
  late final TextEditingController _c;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: widget.sprint.goal);
  }

  @override
  void didUpdateWidget(covariant _SprintGoalField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sprint.id != widget.sprint.id) {
      _c.text = widget.sprint.goal;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 8),
      child: TextField(
        controller: _c,
        onChanged: (v) {
          ref
              .read(sprintRepositoryProvider)
              .update(widget.sprint.copyWith(goal: v));
          ref.invalidate(sprintsListAsyncProvider);
        },
        minLines: 2,
        maxLines: 4,
        style: const TextStyle(fontSize: 13, color: AppColors.text),
        cursorColor: AppColors.accent,
        decoration: InputDecoration(
          hintText: "What's the goal for ${widget.sprint.name}?",
          hintStyle: const TextStyle(color: AppColors.dim, fontSize: 12),
          filled: true,
          fillColor: AppColors.panel2,
          contentPadding: const EdgeInsets.all(8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(6)),
            borderSide: BorderSide(color: AppColors.accent),
          ),
        ),
      ),
    );
  }
}

class _CartTaskRow extends StatefulWidget {
  const _CartTaskRow({
    required this.task,
    required this.surface,
    required this.onUnpin,
    this.onTap,
  });

  final Task task;
  final SprintCartSurface surface;
  final VoidCallback onUnpin;
  final VoidCallback? onTap;

  @override
  State<_CartTaskRow> createState() => _CartTaskRowState();
}

class _CartTaskRowState extends State<_CartTaskRow> {
  bool _rowHover = false;
  bool _xHover = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.task;
    final g = _cartGlyph(t);
    final gColor = kindColor(t.kind);
    final hStr = t.estimate % 1 == 0
        ? '${t.estimate.toInt()}h'
        : '${t.estimate}h';
    final scheduled = t.plannedFor != null;
    Widget buildRow() {
      return MouseRegion(
        onEnter: (_) => setState(() => _rowHover = true),
        onExit: (_) => setState(() => _rowHover = false),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Material(
            color: _rowHover ? AppColors.panel2 : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
            child: InkWell(
              onTap: widget.onTap,
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
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        t.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 36,
                      child: Text(
                        hStr,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                    // Temporarily hidden to match the reference cart row shape.
                    // const SizedBox(width: 4),
                    // SizedBox(
                    //   width: 62,
                    //   child: SprintDayPickerButton(
                    //     task: t,
                    //     child: _CartDayChip(task: t),
                    //   ),
                    // ),
                    const SizedBox(width: 4),
                    if (widget.surface == SprintCartSurface.planner)
                      SizedBox(
                        width: 16,
                        child: MouseRegion(
                          onEnter: (_) => setState(() => _xHover = true),
                          onExit: (_) => setState(() => _xHover = false),
                          child: InkWell(
                            onTap: widget.onUnpin,
                            child: Center(
                              child: Text(
                                '×',
                                style: TextStyle(
                                  fontSize: 16,
                                  height: 1,
                                  color: _xHover
                                      ? const Color(0xFFF87171)
                                      : AppColors.dim,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      SizedBox(
                        width: 40,
                        child: !scheduled
                            ? Center(
                                child: Tooltip(
                                  message: 'No day assigned',
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: AppColors.warn,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                              )
                            : Align(
                                alignment: Alignment.centerRight,
                                child: _TinyDateChip(
                                    date: parseLocalDate(t.plannedFor!)),
                              ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (scheduled) {
      return buildRow();
    }
    return Draggable<Task>(
      data: t,
      maxSimultaneousDrags: 1,
      feedback: Material(
        color: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Card(
            color: AppColors.panel2,
            child: ListTile(
              dense: true,
              title: Text(
                t.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Text(
                hStr,
                style: const TextStyle(fontSize: 11, color: AppColors.muted),
              ),
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.4, child: buildRow()),
      child: buildRow(),
    );
  }
}

// Temporarily hidden to match the reference cart row shape.
// class _CartDayChip extends StatelessWidget {
//   const _CartDayChip({required this.task});
//
//   final Task task;
//
//   @override
//   Widget build(BuildContext context) {
//     final planned = task.plannedFor;
//     final label = planned == null || planned.isEmpty
//         ? 'day'
//         : planned.substring(planned.length - 5);
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
//       decoration: BoxDecoration(
//         color: AppColors.panel2,
//         border: Border.all(color: AppColors.border),
//         borderRadius: BorderRadius.circular(999),
//       ),
//       child: Text(
//         label,
//         textAlign: TextAlign.center,
//         style: const TextStyle(fontSize: 10, color: AppColors.muted),
//       ),
//     );
//   }
// }

class _CartFooter extends StatelessWidget {
  const _CartFooter({required this.surface, required this.onPressed});

  final SprintCartSurface surface;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = surface == SprintCartSurface.planner
        ? 'Sprint View'
        : 'Planner View';
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Material(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
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

class _TinyDateChip extends StatelessWidget {
  const _TinyDateChip({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final label = DateFormat('MMM d').format(date);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.panel2,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 9,
          color: AppColors.muted,
          fontWeight: FontWeight.w500,
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
        label.toUpperCase(),
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
