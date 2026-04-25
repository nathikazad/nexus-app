import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nx_projects/core/formatting/date_label.dart';
import 'package:nx_projects/core/layout/layout.dart';
import 'package:nx_projects/core/theme/app_theme.dart';
import 'package:nx_projects/data/fake/seed_data.dart';
import 'package:nx_projects/data/providers.dart';
import 'package:nx_projects/domain/project/project.dart';
import 'package:nx_projects/domain/sprint/sprint.dart';
import 'package:nx_projects/domain/task/task.dart';
import 'package:nx_projects/domain/task/task_bucket.dart';
import 'package:nx_projects/features/daily/daily_screen.dart';
import 'package:nx_projects/features/filters/filter_sheet.dart';
import 'package:nx_projects/features/filters/filter_state_providers.dart';
import 'package:nx_projects/features/priority/priority_screen.dart';
import 'package:nx_projects/features/projects/projects_screen.dart';
import 'package:nx_projects/features/shared/widgets/context_sheet.dart';
import 'package:nx_projects/features/shell/selection_providers.dart';
import 'package:nx_projects/features/sprint/sprint_screen.dart';
import 'package:nx_projects/features/task_edit/project_edit_sheet.dart';
import 'package:nx_projects/features/task_edit/task_edit_sheet.dart';

class MobileShell extends ConsumerStatefulWidget {
  const MobileShell({super.key});

  @override
  ConsumerState<MobileShell> createState() => _MobileShellState();
}

class _MobileShellState extends ConsumerState<MobileShell> {
  final _search = TextEditingController();
  bool _fabOpen = false;

  @override
  void initState() {
    super.initState();
    _search.text = ref.read(searchQueryProvider);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _openTaskMenu(BuildContext context, WidgetRef r, Task t) {
    showTaskContextSheet(
      context,
      r,
      task: t,
      onAfterChange: () {},
    );
  }

  void _resetDrillOnTabChange(WidgetRef r) {
    r.read(selectedProjectIdProvider.notifier).set(null);
    r.read(selectedSubProjectIdProvider.notifier).set(null);
    r.read(selectedPriorityBucketProvider.notifier).set(null);
  }

  Project? _findProject(List<Project> all, String id) {
    for (final p in all) {
      if (p.id == id) return p;
    }
    return null;
  }

  String _title(WidgetRef r, int tab, List<Project> projects) {
    final pid = r.watch(selectedProjectIdProvider);
    final sid = r.watch(selectedSubProjectIdProvider);
    final bkt = r.watch(selectedPriorityBucketProvider);
    if (tab == 1 && bkt != null) {
      return switch (bkt) {
        TaskBucket.now => 'NOW',
        TaskBucket.next => 'NEXT',
        TaskBucket.later => 'LATER',
        TaskBucket.someday => 'SOMEDAY',
        TaskBucket.unsorted => 'UNSORTED',
      };
    }
    if (tab == 0 && pid != null) {
      final p = _findProject(projects, pid);
      if (sid != null) {
        final sp = _findProject(projects, sid);
        return sp?.name ?? 'Subproject';
      }
      return p?.name ?? 'Project';
    }
    return switch (tab) {
      0 => 'Projects',
      1 => 'Priority',
      2 => 'Sprint',
      _ => 'Daily',
    };
  }

  bool _showBack(WidgetRef r, int tab) {
    if (tab == 1) {
      return r.watch(selectedPriorityBucketProvider) != null;
    }
    if (tab == 0) {
      return r.watch(selectedProjectIdProvider) != null;
    }
    return false;
  }

  void _onBack(WidgetRef r) {
    final tab = r.read(mainTabIndexProvider);
    if (tab == 1) {
      r.read(selectedPriorityBucketProvider.notifier).set(null);
    } else if (tab == 0) {
      final sid = r.read(selectedSubProjectIdProvider);
      if (sid != null) {
        r.read(selectedSubProjectIdProvider.notifier).set(null);
      } else {
        r.read(selectedProjectIdProvider.notifier).set(null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tab = ref.watch(mainTabIndexProvider);
    final projects = ref.watch(projectsListProvider);
    final sprints = ref.watch(sprintsListProvider);
    final sprintIdx = ref.watch(sprintIndexProvider);
    final sp = sprintIdx >= 0 && sprintIdx < sprints.length ? sprints[sprintIdx] : sprints[1];
    final dailyYmd = ref.watch(dailyDateProvider);
    final dailyDate = parseLocalDate(dailyYmd);

    final showSearchRow = tab == 0 || tab == 1;
    final showFilter = tab == 0 && ref.watch(selectedProjectIdProvider) == null;
    final hasActiveFilter = ref.watch(filterKindProvider) != 'all' ||
        ref.watch(filterStatusProvider) != 'all';
    final showBack = _showBack(ref, tab);
    final title = _title(ref, tab, projects);

    final showFab = tab == 0 && ref.watch(selectedProjectIdProvider) != null;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: AppColors.panel,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: AppColors.panel,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final colW = math.min(NxLayout.maxAppWidth, constraints.maxWidth);
            return Center(
              child: Container(
                width: colW,
                decoration: const BoxDecoration(
                  color: AppColors.bg,
                  border: Border(
                    left: BorderSide(color: AppColors.border),
                    right: BorderSide(color: AppColors.border),
                  ),
                ),
                child: Column(
                  children: [
                    _TopBar(
                      title: title,
                      showBack: showBack,
                      onBack: () => _onBack(ref),
                    ),
                    if (tab == 2)
                      _SprintStrip(
                        sp: sp,
                        canPrev: sprintIdx > 0,
                        canNext: sprintIdx < sprints.length - 1,
                        onPrev: () {
                          if (sprintIdx > 0) {
                            ref.read(sprintIndexProvider.notifier).set(sprintIdx - 1);
                          }
                        },
                        onNext: () {
                          if (sprintIdx < sprints.length - 1) {
                            ref.read(sprintIndexProvider.notifier).set(sprintIdx + 1);
                          }
                        },
                      ),
                    if (tab == 2 && sp.goal.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                        decoration: const BoxDecoration(
                          color: AppColors.panel,
                          border: Border(bottom: BorderSide(color: AppColors.border)),
                        ),
                        child: Text(
                          sp.goal,
                          style: const TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                    if (tab == 3)
                      _DailyStrip(
                        dow: longDowLabel(dailyDate),
                        line: fullDateLine(dailyDate),
                        isToday: dailyYmd == kReferenceTodayYmd,
                        onPrev: () {
                          final d = dailyDate.subtract(const Duration(days: 1));
                          ref.read(dailyDateProvider.notifier).set(formatYmd(d));
                        },
                        onNext: () {
                          final d = dailyDate.add(const Duration(days: 1));
                          ref.read(dailyDateProvider.notifier).set(formatYmd(d));
                        },
                      ),
                    if (showSearchRow)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _search,
                                onChanged: (s) {
                                  ref.read(searchQueryProvider.notifier).set(s);
                                },
                                style: const TextStyle(
                                    color: AppColors.text, fontSize: 14, height: 1.45),
                                cursorColor: AppColors.accent,
                                decoration: InputDecoration(
                                  hintText: 'Search tasks…',
                                  hintStyle: const TextStyle(
                                      color: AppColors.muted, fontSize: 14, height: 1.45),
                                  filled: true,
                                  fillColor: AppColors.panel,
                                  isDense: true,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: AppColors.border),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: AppColors.border),
                                  ),
                                  focusedBorder: const OutlineInputBorder(
                                    borderRadius: BorderRadius.all(Radius.circular(10)),
                                    borderSide: BorderSide(color: AppColors.accent, width: 1),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                ),
                              ),
                            ),
                            if (showFilter) ...[
                              const SizedBox(width: 8),
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  _FilterButton(
                                    hasActive: hasActiveFilter,
                                    onPressed: () => showFilterSheet(context, ref),
                                  ),
                                  if (hasActiveFilter)
                                    const Positioned(
                                      right: 4,
                                      top: 2,
                                      child: Icon(
                                          Icons.circle, size: 6, color: AppColors.accent),
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    Expanded(
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: IndexedStack(
                              index: tab,
                              children: [
                                ProjectsScreen(onOpenTaskMenu: _openTaskMenu),
                                PriorityScreen(onOpenTaskMenu: _openTaskMenu),
                                SprintScreen(onOpenTaskMenu: _openTaskMenu),
                                DailyScreen(onOpenTaskMenu: _openTaskMenu),
                              ],
                            ),
                          ),
                          if (showFab)
                            Positioned(
                              right: 16,
                              bottom: 8,
                              child: _Fab(
                                isOpen: _fabOpen,
                                onToggle: () => setState(() => _fabOpen = !_fabOpen),
                                onNewTask: () {
                                  setState(() => _fabOpen = false);
                                  final pid = ref.read(selectedProjectIdProvider);
                                  final sid = ref.read(selectedSubProjectIdProvider);
                                  showTaskEditSheet(
                                    context,
                                    ref,
                                    defaultProject: pid,
                                    defaultSub: sid,
                                    onSave: () {},
                                  );
                                },
                                onNewProject: () {
                                  setState(() => _fabOpen = false);
                                  showProjectEditSheet(context, ref, onSave: () {});
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                    _RefBottomNav(
                      current: tab,
                      onChanged: (i) {
                        if (i != ref.read(mainTabIndexProvider)) {
                          _resetDrillOnTabChange(ref);
                        }
                        ref.read(mainTabIndexProvider.notifier).setTab(i);
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Reference `index.html` `.bottom-nav` — no Material 3 `NavigationBar` pill.
class _RefBottomNav extends StatelessWidget {
  const _RefBottomNav({required this.current, required this.onChanged});

  final int current;
  final ValueChanged<int> onChanged;

  static const _items = <(String, String)>[
    ('▦', 'Projects'),
    ('☰', 'Priority'),
    ('◈', 'Sprint'),
    ('◉', 'Daily'),
  ];

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    return Material(
      color: AppColors.panel,
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        padding: EdgeInsets.fromLTRB(0, 4, 0, math.max(4, safeBottom)),
        child: Row(
          children: [
            for (var i = 0; i < _items.length; i++)
              Expanded(
                child: _NavItem(
                  icon: _items[i].$1,
                  label: _items[i].$2,
                  active: current == i,
                  onTap: () => onChanged(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String icon, label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                icon,
                style: TextStyle(
                  fontSize: 20,
                  height: 1,
                  color: active ? AppColors.accent : AppColors.dim,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.02,
                  color: active ? AppColors.accent : AppColors.dim,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.hasActive, required this.onPressed});

  final bool hasActive;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.panel,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: hasActive ? AppColors.accent : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('⚙', style: TextStyle(fontSize: 14, color: hasActive ? AppColors.accent : AppColors.muted)),
              const SizedBox(width: 6),
              Text(
                'Filters',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: hasActive ? AppColors.accent : AppColors.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.showBack,
    required this.onBack,
  });

  final String title;
  final bool showBack;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.panel,
      child: SafeArea(
        bottom: false,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: NxLayout.topBarMinH),
          child: Container(
            width: double.infinity,
            padding: NxLayout.topBarHPadding,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                if (showBack) _TopBarBackButton(onBack: onBack) else const _TopBarLogo(),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Spacer(),
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.panel2,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Text('N', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBarLogo extends StatelessWidget {
  const _TopBarLogo();

  @override
  Widget build(BuildContext context) {
    return const Text(
      '◆ Nexus',
      style: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 15,
        letterSpacing: 0.3,
        color: AppColors.text,
      ),
    );
  }
}

class _TopBarBackButton extends StatelessWidget {
  const _TopBarBackButton({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onBack,
        borderRadius: BorderRadius.circular(8),
        child: const SizedBox(
          width: 32,
          height: 32,
          child: Center(
            child: Text('‹', style: TextStyle(color: AppColors.muted, fontSize: 22, height: 1)),
          ),
        ),
      ),
    );
  }
}

class _SprintStrip extends StatelessWidget {
  const _SprintStrip({
    required this.sp,
    required this.onPrev,
    required this.onNext,
    required this.canPrev,
    required this.canNext,
  });

  final Sprint sp;
  final VoidCallback onPrev, onNext;
  final bool canPrev, canNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: const BoxDecoration(
        color: AppColors.panel,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          _SprintStripChev(
            label: '‹',
            onPressed: canPrev ? onPrev : null,
          ),
          const SizedBox(width: 10),
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
                        fontSize: 15,
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
          const SizedBox(width: 10),
          _SprintStripChev(
            label: '›',
            onPressed: canNext ? onNext : null,
          ),
        ],
      ),
    );
  }
}

class _SprintStripChev extends StatelessWidget {
  const _SprintStripChev({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 32,
          height: 32,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 18,
                height: 1,
                color: enabled ? AppColors.muted : AppColors.dim,
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
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
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

class _DailyStrip extends StatelessWidget {
  const _DailyStrip({
    required this.dow,
    required this.line,
    required this.isToday,
    required this.onPrev,
    required this.onNext,
  });

  final String dow, line;
  final bool isToday;
  final VoidCallback onPrev, onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: const BoxDecoration(
        color: AppColors.panel,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          _SprintStripChev(
            label: '‹',
            onPressed: onPrev,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      dow,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: AppColors.text,
                      ),
                    ),
                    if (isToday) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'today',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                            color: AppColors.bg,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(line, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _SprintStripChev(
            label: '›',
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}

class _Fab extends StatelessWidget {
  const _Fab({
    required this.isOpen,
    required this.onToggle,
    required this.onNewTask,
    required this.onNewProject,
  });

  final bool isOpen;
  final VoidCallback onToggle, onNewTask, onNewProject;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (isOpen) ...[
          _FabMenuPill(
            onPressed: onNewProject,
            label: 'Project',
          ),
          const SizedBox(height: 8),
          _FabMenuPill(
            onPressed: onNewTask,
            label: 'Task',
          ),
          const SizedBox(height: 8),
        ],
        _FabMainButton(
          isOpen: isOpen,
          onPressed: onToggle,
        ),
      ],
    );
  }
}

class _FabMenuPill extends StatelessWidget {
  const _FabMenuPill({required this.onPressed, required this.label});

  final VoidCallback onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.panel2,
      borderRadius: BorderRadius.circular(999),
      elevation: 0,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.border2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                offset: Offset(0, 6),
                blurRadius: 20,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '+',
                style: TextStyle(
                  color: AppColors.accent,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FabMainButton extends StatelessWidget {
  const _FabMainButton({required this.isOpen, required this.onPressed});

  final bool isOpen;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.accent,
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Container(
          width: NxLayout.fabSize,
          height: NxLayout.fabSize,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Color(0x596AA3FF),
                offset: Offset(0, 10),
                blurRadius: 28,
              ),
            ],
          ),
          child: Center(
            child: Transform.rotate(
              angle: isOpen ? 0.78539816339 : 0,
              child: const Text(
                '+',
                style: TextStyle(
                  color: AppColors.bg,
                  fontSize: 28,
                  height: 1,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
