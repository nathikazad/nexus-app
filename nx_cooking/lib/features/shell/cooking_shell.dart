import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_cooking/core/dates/week_calendar.dart';
import 'package:nx_cooking/core/theme/app_theme.dart';
import 'package:nx_cooking/data/providers.dart';
import 'package:nx_cooking/features/buy/buy_page.dart';
import 'package:nx_cooking/features/recipes/recipes_page.dart';
import 'package:nx_cooking/features/stats/stats_page.dart';
import 'package:nx_cooking/features/week/week_page.dart';
import 'package:nx_db/auth.dart';
import 'package:solar_icon_pack/solar_icon_pack.dart';

const _tabTitles = ['Week', 'Recipes', 'Buy', 'Stats'];

/// Bottom-nav scaffold per `reference/index.html` + [nx_time] `AppShell` pattern.
class CookingShell extends ConsumerStatefulWidget {
  const CookingShell({super.key});

  @override
  ConsumerState<CookingShell> createState() => _CookingShellState();
}

class _CookingShellState extends ConsumerState<CookingShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _TopBar(
            title: _tabTitles[_index],
            onLogout: () => ref.read(authProvider.notifier).logout(),
          ),
          if (_index == 0)
            Consumer(
              builder: (context, ref, _) {
                final start = ref.watch(selectedWeekStartProvider);
                return _WeekSubBar(
                  label: formatWeekRangeLabel(start),
                  onPrev: () => ref
                      .read(selectedWeekStartProvider.notifier)
                      .shiftWeeks(-1),
                  onNext: () => ref
                      .read(selectedWeekStartProvider.notifier)
                      .shiftWeeks(1),
                );
              },
            ),
          if (_index == 1) const _RecipesSubBar(),
          Expanded(
            child: IndexedStack(
              index: _index,
              children: const [
                WeekPage(),
                RecipesPage(),
                BuyPage(),
                StatsPage(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _BottomNav(
        currentIndex: _index,
        onChanged: (i) => setState(() => _index = i),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title, required this.onLogout});

  final String title;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.95),
      child: Container(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.orange100)),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                const SizedBox(width: 28),
                Expanded(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.orange500,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Account',
                  onSelected: (value) {
                    if (value == 'logout') onLogout();
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'logout', child: Text('Log out')),
                  ],
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.orange50,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: AppColors.orange200.withValues(alpha: 0.6),
                      ),
                    ),
                    child: const Icon(
                      SolarLinearIcons.userRounded,
                      size: 16,
                      color: AppColors.orange500,
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

class _WeekSubBar extends StatelessWidget {
  const _WeekSubBar({
    required this.label,
    required this.onPrev,
    required this.onNext,
  });

  final String label;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.95),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.zinc100)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              onPressed: onPrev,
              style: IconButton.styleFrom(foregroundColor: AppColors.zinc400),
              icon: const Icon(SolarLinearIcons.altArrowLeft, size: 20),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
                color: AppColors.zinc800,
              ),
            ),
            IconButton(
              onPressed: onNext,
              style: IconButton.styleFrom(foregroundColor: AppColors.zinc400),
              icon: const Icon(SolarLinearIcons.altArrowRight, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecipesSubBar extends StatelessWidget {
  const _RecipesSubBar();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.95),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.zinc100)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              decoration: InputDecoration(
                hintText: 'Search recipes...',
                hintStyle: const TextStyle(
                  color: AppColors.zinc400,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                prefixIcon: const Icon(
                  SolarLinearIcons.magnifer,
                  size: 18,
                  color: AppColors.zinc400,
                ),
                filled: true,
                fillColor: AppColors.zinc50,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.zinc200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.zinc200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: AppColors.orange500,
                    width: 1.2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Consumer(
              builder: (context, ref, _) {
                final async = ref.watch(recipeListProvider);
                final n = async.maybeWhen(
                  data: (list) => list.length,
                  orElse: () => 0,
                );
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$n recipes',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                        color: AppColors.zinc500,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {},
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.zinc500,
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(
                        SolarLinearIcons.sortFromTopToBottom,
                        size: 14,
                      ),
                      label: const Text(
                        'Recent',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.currentIndex, required this.onChanged});

  final int currentIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.95),
      child: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.orange100)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 22),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  label: 'Week',
                  icon: SolarLinearIcons.calendar,
                  selected: currentIndex == 0,
                  onTap: () => onChanged(0),
                ),
                _NavItem(
                  label: 'Recipes',
                  icon: SolarLinearIcons.book,
                  selected: currentIndex == 1,
                  onTap: () => onChanged(1),
                ),
                _NavItem(
                  label: 'Buy',
                  icon: SolarLinearIcons.cartLarge,
                  selected: currentIndex == 2,
                  onTap: () => onChanged(2),
                ),
                _NavItem(
                  label: 'Stats',
                  icon: SolarLinearIcons.pieChart,
                  selected: currentIndex == 3,
                  onTap: () => onChanged(3),
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
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.orange500 : AppColors.zinc400;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.4,
                fontWeight: FontWeight.w500,
                color: color,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
