import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nx_cooking/core/layout/layout.dart';
import 'package:nx_cooking/core/theme/app_theme.dart';
import 'package:nx_cooking/data/providers.dart';
import 'package:nx_cooking/domain/meal_status.dart';
import 'package:nx_cooking/domain/week_section.dart';
import 'package:solar_icon_pack/solar_icon_pack.dart';

class WeekPage extends ConsumerWidget {
  const WeekPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(weekSectionsProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Could not load week.\n$e',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.zinc600),
          ),
        ),
      ),
      data: (days) {
        final withMeals = days
            .where((d) => d.meal != null)
            .toList(growable: false);
        final bottomPad = CookingLayout.bottomNavExtra + 88;
        if (withMeals.isEmpty) {
          return ListView(
            padding: EdgeInsets.fromLTRB(
              CookingLayout.screenPadding,
              40,
              CookingLayout.screenPadding,
              bottomPad,
            ),
            children: const [
              Icon(
                SolarLinearIcons.calendar,
                size: 40,
                color: AppColors.zinc300,
              ),
              SizedBox(height: 16),
              Text(
                'Nothing planned this week',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.zinc600,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Plan a recipe from the Recipes tab or pick a different week.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.zinc500),
              ),
            ],
          );
        }
        return ListView.builder(
          padding: EdgeInsets.fromLTRB(
            CookingLayout.screenPadding,
            20,
            CookingLayout.screenPadding,
            bottomPad,
          ),
          itemCount: withMeals.length,
          itemBuilder: (context, i) => _DayBlock(section: withMeals[i]),
        );
      },
    );
  }
}

class _DayBlock extends StatelessWidget {
  const _DayBlock({required this.section});

  final WeekDaySection section;

  @override
  Widget build(BuildContext context) {
    final meal = section.meal;
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                section.dayLabel.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10.4,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  color: AppColors.zinc400,
                ),
              ),
              if (section.isToday)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.orange100.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'TODAY',
                    style: TextStyle(
                      fontSize: 10.4,
                      fontWeight: FontWeight.w600,
                      color: AppColors.orange600,
                    ),
                  ),
                ),
            ],
          ),
          if (meal != null) ...[
            const SizedBox(height: 10),
            _MealCardTile(meal: meal),
          ],
        ],
      ),
    );
  }
}

class _MealCardTile extends StatelessWidget {
  const _MealCardTile({required this.meal});

  final WeekMealCard meal;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => context.push('/plan/${meal.planId}'),
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: _cardDecoration(),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        meal.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              meal.kind == MealCardKind.cookingInProgress
                              ? FontWeight.w600
                              : FontWeight.w500,
                          height: 1.25,
                          color: meal.kind == MealCardKind.done
                              ? AppColors.zinc400
                              : AppColors.zinc900,
                          decoration: meal.kind == MealCardKind.done
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                          decorationColor: AppColors.zinc300,
                        ),
                      ),
                    ),
                    if (meal.badge.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _badgeBackground(),
                          borderRadius: BorderRadius.circular(6),
                          border: meal.kind == MealCardKind.planned
                              ? Border.all(color: AppColors.zinc100)
                              : null,
                        ),
                        child: Text(
                          meal.badge,
                          style: TextStyle(
                            fontSize: 10.4,
                            fontWeight: FontWeight.w500,
                            color: _badgeForeground(),
                          ),
                        ),
                      ),
                    if (meal.kind == MealCardKind.done) ...[
                      const SizedBox(width: 6),
                      const Icon(
                        SolarLinearIcons.checkCircle,
                        size: 18,
                        color: AppColors.zinc400,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (meal.showPing) ...[
                      const _LiveDot(),
                      const SizedBox(width: 6),
                    ] else
                      Container(
                        width: 5,
                        height: 5,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: meal.kind == MealCardKind.planned
                              ? AppColors.zinc200
                              : AppColors.zinc300,
                          shape: BoxShape.circle,
                        ),
                      ),
                    Expanded(
                      child: Text(
                        meal.subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: _subtitleColor(),
                          fontWeight:
                              meal.kind == MealCardKind.cookingInProgress
                              ? FontWeight.w500
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _subtitleColor() {
    return switch (meal.kind) {
      MealCardKind.cookingInProgress => AppColors.orange700,
      MealCardKind.planned => AppColors.zinc400,
      MealCardKind.done => AppColors.zinc400,
    };
  }

  Color _badgeBackground() {
    return switch (meal.kind) {
      MealCardKind.cookingInProgress => AppColors.orange100,
      MealCardKind.planned => AppColors.zinc50,
      MealCardKind.done => AppColors.zinc100,
    };
  }

  Color _badgeForeground() {
    return switch (meal.kind) {
      MealCardKind.cookingInProgress => AppColors.orange700,
      MealCardKind.planned => AppColors.zinc400,
      MealCardKind.done => AppColors.zinc500,
    };
  }

  BoxDecoration _cardDecoration() {
    if (meal.kind == MealCardKind.cookingInProgress) {
      return BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF7ED), Colors.white],
        ),
        border: Border.all(color: AppColors.orange200.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: AppColors.orange500.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      );
    }
    if (meal.kind == MealCardKind.done) {
      return BoxDecoration(
        color: AppColors.zinc50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.zinc100),
      );
    }
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.zinc100),
    );
  }
}

class _LiveDot extends StatelessWidget {
  const _LiveDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.orange500,
        boxShadow: [
          BoxShadow(
            color: AppColors.orange400.withValues(alpha: 0.5),
            blurRadius: 4,
          ),
        ],
      ),
    );
  }
}
