import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nx_cooking/core/theme/app_theme.dart';
import 'package:nx_cooking/data/providers.dart';
import 'package:nx_cooking/domain/recipe_detail.dart';
import 'package:solar_icon_pack/solar_icon_pack.dart';

/// Read-only recipe detail (HTML reference: recipe detail overlay).
class RecipeViewPage extends ConsumerWidget {
  const RecipeViewPage({super.key, required this.recipeId});

  final int recipeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(recipeDetailProvider(recipeId));
    return async.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(SolarLinearIcons.altArrowLeft, size: 22),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Error: $e', textAlign: TextAlign.center),
          ),
        ),
      ),
      data: (RecipeDetail? detail) {
        if (detail == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Recipe'),
              leading: IconButton(
                icon: const Icon(SolarLinearIcons.altArrowLeft, size: 22),
                onPressed: () => context.pop(),
              ),
            ),
            body: const Center(
              child: Text('Recipe not found'),
            ),
          );
        }
        return _RecipeViewBody(detail: detail, recipeId: recipeId);
      },
    );
  }
}

class _RecipeViewBody extends StatelessWidget {
  const _RecipeViewBody({required this.detail, required this.recipeId});

  final RecipeDetail detail;
  final int recipeId;

  @override
  Widget build(BuildContext context) {
    final paddingBottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _TopBar(
            onBack: () => context.pop(),
            onEdit: () => context.push('/recipe/$recipeId/edit'),
          ),
          const Divider(height: 1, color: AppColors.orange100),
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _Header(detail: detail),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(22, 8, 22, 120),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _ReadOnlyIngredients(ingredients: detail.ingredients),
                      const SizedBox(height: 28),
                      _InstructionsBlock(lines: detail.instructionLines),
                      if (detail.notes != null && detail.notes!.isNotEmpty) ...[
                        const SizedBox(height: 28),
                        _NotesBlock(notes: detail.notes!),
                      ],
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _FooterActions(
        onAddToWeek: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Add to week (coming soon)')),
          );
        },
        onCookNow: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cook now (coming soon)')),
          );
        },
        paddingBottom: paddingBottom,
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack, required this.onEdit});

  final VoidCallback onBack;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(SolarLinearIcons.altArrowLeft, size: 22),
              color: AppColors.zinc500,
              onPressed: onBack,
            ),
            const Expanded(
              child: Text(
                'Recipe',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.zinc900,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(SolarLinearIcons.penNewRound, size: 20),
              color: AppColors.zinc500,
              onPressed: onEdit,
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.detail});

  final RecipeDetail detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.orange100)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (detail.tags.isNotEmpty)
            Wrap(
              spacing: 5,
              runSpacing: 5,
              children: detail.tags
                  .map(
                    (t) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.orange100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        t.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 9.6,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                          color: AppColors.orange800,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          if (detail.tags.isNotEmpty) const SizedBox(height: 12),
          Text(
            detail.title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              height: 1.15,
              color: AppColors.zinc900,
            ),
          ),
          const SizedBox(height: 8),
          _Meta(detail: detail),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.detail});

  final RecipeDetail detail;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    if (detail.prepTimeMinutes != null) {
      items.add(
        _MetaItem(
          icon: SolarLinearIcons.stopwatch,
          text: '${detail.prepTimeMinutes} min',
        ),
      );
    }
    if (detail.servings != null) {
      items.add(
        _MetaItem(
          icon: SolarLinearIcons.userRounded,
          text: '${detail.servings} servings',
        ),
      );
    }
    if (detail.lastCookedLabel != null) {
      items.add(
        _MetaItem(
          icon: SolarLinearIcons.chefHatMinimalistic,
          text: detail.lastCookedLabel!,
        ),
      );
    }
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    return Wrap(
      spacing: 16,
      runSpacing: 4,
      children: items,
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.zinc400),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.zinc500,
          ),
        ),
      ],
    );
  }
}

class _ReadOnlyIngredients extends StatelessWidget {
  const _ReadOnlyIngredients({required this.ingredients});

  final List<IngredientLine> ingredients;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'INGREDIENTS',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
            color: AppColors.zinc400,
          ),
        ),
        const SizedBox(height: 12),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.zinc200),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              for (var i = 0; i < ingredients.length; i++) ...[
                if (i > 0) const Divider(height: 1, color: AppColors.zinc100),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          ingredients[i].name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.zinc900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (ingredients[i].amount.isNotEmpty)
                        Text(
                          ingredients[i].amount,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.zinc400,
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

class _InstructionsBlock extends StatelessWidget {
  const _InstructionsBlock({required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) {
      return const Text(
        'No instructions',
        style: TextStyle(color: AppColors.zinc500),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'INSTRUCTIONS',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
            color: AppColors.zinc400,
          ),
        ),
        const SizedBox(height: 12),
        ...List.generate(lines.length, (i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Text.rich(
              TextSpan(
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: AppColors.zinc600,
                ),
                children: [
                  TextSpan(
                    text: '${i + 1}. ',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.orange500,
                    ),
                  ),
                  TextSpan(text: lines[i]),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _NotesBlock extends StatelessWidget {
  const _NotesBlock({required this.notes});

  final String notes;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'NOTES',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
            color: AppColors.zinc400,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          notes,
          style: const TextStyle(
            fontSize: 14,
            height: 1.45,
            color: AppColors.zinc500,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}

class _FooterActions extends StatelessWidget {
  const _FooterActions({
    required this.onAddToWeek,
    required this.onCookNow,
    required this.paddingBottom,
  });

  final VoidCallback onAddToWeek;
  final VoidCallback onCookNow;
  final double paddingBottom;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.95),
      elevation: 8,
      child: Container(
        padding: EdgeInsets.fromLTRB(18, 12, 18, 22 + paddingBottom),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.orange100)),
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onAddToWeek,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.zinc700,
                  side: const BorderSide(color: AppColors.zinc200),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(SolarLinearIcons.calendarAdd, size: 16),
                label: const Text(
                  'Add to Week',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: onCookNow,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.orange500,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(
                  SolarLinearIcons.chefHatMinimalistic,
                  size: 16,
                ),
                label: const Text(
                  'Cook Now',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
