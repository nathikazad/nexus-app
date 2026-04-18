import 'package:flutter/material.dart';
import 'package:solar_icon_pack/solar_icon_pack.dart';

import '../../data/fake_today_repository.dart';
import '../../theme/app_colors.dart';
import '../calendar/calendar_page.dart';
import '../goals/goals_page.dart';
import '../tasks/tasks_page.dart';
import '../today/today_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, this.todayRepository, this.initialTabIndex = 0});

  final FakeTodayRepository? todayRepository;

  /// Initial bottom-nav index (0–3). Used by screenshot integration tests.
  final int initialTabIndex;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late int _index;

  late final FakeTodayRepository _repo = widget.todayRepository ?? FakeTodayRepository();

  @override
  void initState() {
    super.initState();
    final i = widget.initialTabIndex;
    _index = i < 0 ? 0 : (i > 3 ? 3 : i);
  }

  void _onAiTap() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('AI assistant — not in scope for this build.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _repo.getToday();

    return Scaffold(
      backgroundColor: Colors.white,
      body: IndexedStack(
        index: _index,
        children: [
          TodayPage(
            snapshot: snapshot,
            onActivityTap: (_) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Activity detail — coming soon.')),
              );
            },
            onAddManualTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Add time block — coming soon.')),
              );
            },
          ),
          const TasksPage(),
          const GoalsPage(),
          const CalendarPage(),
        ],
      ),
      bottomNavigationBar: _BottomNav(
        currentIndex: _index,
        onChanged: (i) => setState(() => _index = i),
        onAiTap: _onAiTap,
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.currentIndex,
    required this.onChanged,
    required this.onAiTap,
  });

  final int currentIndex;
  final ValueChanged<int> onChanged;
  final VoidCallback onAiTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.92),
      elevation: 0,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.slate100)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 80,
            child: Row(
              children: [
                Expanded(
                  child: _NavItem(
                    label: 'Today',
                    icon: SolarLinearIcons.pieChart2,
                    selected: currentIndex == 0,
                    onTap: () => onChanged(0),
                  ),
                ),
                Expanded(
                  child: _NavItem(
                    label: 'Tasks',
                    icon: SolarLinearIcons.checklistMinimalistic,
                    selected: currentIndex == 1,
                    onTap: () => onChanged(1),
                    badge: true,
                  ),
                ),
                Expanded(child: _AiSlot(onTap: onAiTap)),
                Expanded(
                  child: _NavItem(
                    label: 'Goals',
                    icon: SolarLinearIcons.target,
                    selected: currentIndex == 2,
                    onTap: () => onChanged(2),
                  ),
                ),
                Expanded(
                  child: _NavItem(
                    label: 'Calendar',
                    icon: SolarLinearIcons.calendarMark,
                    selected: currentIndex == 3,
                    onTap: () => onChanged(3),
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

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.badge = false,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.accent : AppColors.slate400;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 26,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Icon(icon, size: 26, color: color),
                  if (badge)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiSlot extends StatelessWidget {
  const _AiSlot({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned(
            top: -14,
            child: Material(
              color: AppColors.accent,
              shape: const CircleBorder(
                side: BorderSide(color: Colors.white, width: 4),
              ),
              elevation: 2,
              shadowColor: Colors.black26,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onTap,
                child: const SizedBox(
                  width: 48,
                  height: 48,
                  child: Icon(
                    SolarLinearIcons.stars,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
