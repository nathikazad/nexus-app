import 'package:flutter/material.dart' hide Action;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icon_pack/solar_icon_pack.dart';

import 'package:nx_time/core/theme/app_theme.dart';
import 'package:nx_time/data/providers.dart';
import 'package:nx_time/domain/action/action.dart';
import 'package:nx_time/features/action_detail/action_detail_page.dart';
import 'package:nx_time/features/action_detail/action_detail_view_model.dart';
import 'package:nx_time/features/action_edit/action_edit_page.dart';
import 'package:nx_time/features/ai/ai_chat_page.dart';
import 'package:nx_time/features/ai/voice_listening_overlay.dart';
import 'package:nx_time/features/calendar/calendar_page.dart';
import 'package:nx_time/features/goals/goals_page.dart';
import 'package:nx_time/features/tasks/tasks_page.dart';
import 'package:nx_time/features/today/today_page.dart';
import 'package:nx_time/features/today/today_view_model.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, this.initialTabIndex = 0});

  /// Initial bottom-nav index (0–3). Used by screenshot integration tests.
  final int initialTabIndex;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  late int _index;

  @override
  void initState() {
    super.initState();
    final i = widget.initialTabIndex;
    _index = i < 0 ? 0 : (i > 3 ? 3 : i);
  }

  void _onAiTap() {
    Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, __, ___) => const AiChatPage(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  void _onAiLongPress() {
    showVoiceListeningOverlay(context);
  }

  @override
  Widget build(BuildContext context) {
    final snapshotAsync = ref.watch(todaySnapshotProvider);
    final colors = modelTypeColorsOrFallback(
      ref.watch(modelTypeColorsProvider),
    );

    ref.listen<AsyncValue<TodaySnapshot>>(todaySnapshotProvider, (prev, next) {
      if (next.hasError) {
        debugPrint('[nx_time shell] todaySnapshot: ${next.error}');
      }
    });

    return Scaffold(
      backgroundColor: Colors.white,
      body: IndexedStack(
        index: _index,
        children: [
          snapshotAsync.when(
            data: (snapshot) => TodayPage(
              snapshot: snapshot,
              onActivityTap: (index) {
                final row = index < snapshot.umbrellaRows.length
                    ? snapshot.umbrellaRows[index]
                    : null;
                final Action? rowAction =
                    index < snapshot.sourceActions.length ? snapshot.sourceActions[index] : null;
                late final ActivityDetailArgs args;
                if (row != null && row.children.isNotEmpty) {
                  args = activityDetailArgsForUmbrella(row, snapshot.dayDateLabel, colors);
                } else if (rowAction != null) {
                  args = activityDetailArgsForAction(rowAction, snapshot.dayDateLabel, colors);
                } else {
                  args = activityDetailArgsForTodayRow(
                    snapshot.actions[index],
                    snapshot.dayDateLabel,
                  );
                }
                Navigator.of(context).push<void>(
                  MaterialPageRoute(builder: (_) => ActivityDetailPage(args: args)),
                );
              },
              onChildTap: (rowIndex, childIndex) {
                final row = snapshot.umbrellaRows[rowIndex];
                if (childIndex < 0 || childIndex >= row.children.length) return;
                final child = row.children[childIndex];
                final args = activityDetailArgsForAction(child, snapshot.dayDateLabel, colors);
                Navigator.of(context).push<void>(
                  MaterialPageRoute(builder: (_) => ActivityDetailPage(args: args)),
                );
              },
              onAddManualTap: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const ActionEditPage(),
                  ),
                );
              },
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Could not load Actions: $e'),
              ),
            ),
          ),
          TasksPage(),
          const GoalsPage(),
          _index == 3 ? const CalendarPage() : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: _BottomNav(
        currentIndex: _index,
        onChanged: (i) => setState(() => _index = i),
        onAiTap: _onAiTap,
        onAiLongPress: _onAiLongPress,
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.currentIndex,
    required this.onChanged,
    required this.onAiTap,
    required this.onAiLongPress,
  });

  final int currentIndex;
  final ValueChanged<int> onChanged;
  final VoidCallback onAiTap;
  final VoidCallback onAiLongPress;

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
                    label: 'Actions',
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
                Expanded(child: _AiSlot(onTap: onAiTap, onLongPress: onAiLongPress)),
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
  const _AiSlot({required this.onTap, required this.onLongPress});

  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned(
            top: -22,
            child: Material(
              color: AppColors.accent,
              shape: const CircleBorder(
                side: BorderSide(color: Colors.white, width: 4),
              ),
              elevation: 4,
              shadowColor: Colors.black26,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onTap,
                onLongPress: onLongPress,
                child: const SizedBox(
                  width: 60,
                  height: 60,
                  child: Icon(
                    SolarBoldIcons.bolt,
                    color: Colors.white,
                    size: 28,
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
