import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_cooking/core/layout/layout.dart';
import 'package:nx_cooking/core/theme/app_theme.dart';
import 'package:nx_cooking/data/providers.dart';
import 'package:solar_icon_pack/solar_icon_pack.dart';

class StatsPage extends ConsumerWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(cookingRepositoryProvider).stats;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        CookingLayout.screenPadding,
        20,
        CookingLayout.screenPadding,
        CookingLayout.bottomNavExtra + 88,
      ),
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                highlight: true,
                icon: SolarLinearIcons.chefHatMinimalistic,
                value: s.mealsCooked,
                label: 'Meals cooked',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                highlight: false,
                icon: SolarLinearIcons.stopwatch,
                value: s.totalTimeLabel,
                label: 'Total time',
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const Text(
          'COOKED THIS WEEK',
          style: TextStyle(
            fontSize: 10.4,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            color: Color(0xCC9A3412),
          ),
        ),
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(
              color: AppColors.orange100.withValues(alpha: 0.4),
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppColors.orange500.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            children: [
              for (var i = 0; i < s.cookedThisWeek.length; i++) ...[
                if (i > 0) const Divider(height: 1, color: AppColors.zinc100),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.cookedThisWeek[i].title,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.zinc900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              s.cookedThisWeek[i].whenLabel,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.zinc500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        s.cookedThisWeek[i].durationLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.orange600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.highlight,
    required this.icon,
    required this.value,
    required this.label,
  });

  final bool highlight;
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: highlight
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFFF7ED), Colors.white],
                )
              : null,
          color: highlight ? null : Colors.white,
          border: Border.all(
            color: highlight
                ? AppColors.orange200.withValues(alpha: 0.5)
                : AppColors.zinc200,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.orange500.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(
              icon,
              size: 22,
              color: highlight ? AppColors.orange500 : AppColors.zinc400,
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                    color: AppColors.zinc900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10.4,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                    color: AppColors.zinc500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
