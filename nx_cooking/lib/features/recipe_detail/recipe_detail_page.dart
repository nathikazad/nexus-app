import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nx_cooking/core/theme/app_theme.dart';
import 'package:nx_cooking/data/providers.dart';
import 'package:nx_cooking/domain/recipe_detail.dart';
import 'package:solar_icon_pack/solar_icon_pack.dart';

class RecipeDetailPage extends ConsumerStatefulWidget {
  const RecipeDetailPage({super.key, required this.recipeId});

  final String recipeId;

  @override
  ConsumerState<RecipeDetailPage> createState() => _RecipeDetailPageState();
}

class _RecipeDetailPageState extends ConsumerState<RecipeDetailPage> {
  List<bool>? _ingredientChecks;

  @override
  Widget build(BuildContext context) {
    final detail = ref
        .watch(cookingRepositoryProvider)
        .recipeDetailById(widget.recipeId);
    if (detail == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(SolarLinearIcons.altArrowLeft),
            onPressed: () => context.pop(),
          ),
          title: const Text('Recipe'),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'No demo detail for this recipe yet — connect PGDB later.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    _ingredientChecks ??= detail.ingredients
        .map((e) => e.initialChecked)
        .toList();

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(SolarLinearIcons.altArrowLeft, size: 22),
                    color: AppColors.zinc500,
                    onPressed: () => context.pop(),
                  ),
                  const Expanded(
                    child: Text(
                      'Recipe Details',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.zinc900,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(SolarLinearIcons.menuDotsCircle, size: 22),
                    color: AppColors.zinc500,
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.orange100),
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _HeaderBlock(detail: detail)),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(22, 8, 22, 120),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _IngredientsBlock(
                        detail: detail,
                        checks: _ingredientChecks!,
                        onToggle: (i, v) =>
                            setState(() => _ingredientChecks![i] = v),
                      ),
                      const SizedBox(height: 28),
                      _InstructionsBlock(lines: detail.instructionLines),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _BottomActions(
        onCancel: () => context.pop(),
        onMarkDone: () => context.pop(),
      ),
    );
  }
}

class _HeaderBlock extends StatelessWidget {
  const _HeaderBlock({required this.detail});

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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.orange100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.orange500,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  detail.statusChip.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10.4,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                    color: AppColors.orange800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            detail.title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              height: 1.15,
              color: AppColors.zinc900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            detail.headerLine,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.zinc500,
            ),
          ),
        ],
      ),
    );
  }
}

class _IngredientsBlock extends StatelessWidget {
  const _IngredientsBlock({
    required this.detail,
    required this.checks,
    required this.onToggle,
  });

  final RecipeDetail detail;
  final List<bool> checks;
  final void Function(int index, bool value) onToggle;

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
              for (var i = 0; i < detail.ingredients.length; i++) ...[
                if (i > 0) const Divider(height: 1, color: AppColors.zinc100),
                _IngredientRow(
                  name: detail.ingredients[i].name,
                  amount: detail.ingredients[i].amount,
                  checked: checks[i],
                  onChanged: (v) => onToggle(i, v),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _IngredientRow extends StatelessWidget {
  const _IngredientRow({
    required this.name,
    required this.amount,
    required this.checked,
    required this.onChanged,
  });

  final String name;
  final String amount;
  final bool checked;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: () => onChanged(!checked),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: Checkbox(
                  value: checked,
                  onChanged: (v) => onChanged(v ?? false),
                  fillColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return AppColors.orange500;
                    }
                    return Colors.transparent;
                  }),
                  checkColor: Colors.white,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  side: const BorderSide(color: AppColors.zinc300, width: 1.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: checked ? AppColors.zinc400 : AppColors.zinc900,
                    decoration: checked ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              Text(
                amount,
                style: const TextStyle(fontSize: 14, color: AppColors.zinc400),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InstructionsBlock extends StatelessWidget {
  const _InstructionsBlock({required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
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

class _BottomActions extends StatelessWidget {
  const _BottomActions({required this.onCancel, required this.onMarkDone});

  final VoidCallback onCancel;
  final VoidCallback onMarkDone;

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return Material(
      color: Colors.white.withValues(alpha: 0.95),
      elevation: 8,
      child: Container(
        padding: EdgeInsets.fromLTRB(18, 12, 18, 22 + pad.bottom),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.orange100)),
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onCancel,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.zinc700,
                  side: const BorderSide(color: AppColors.zinc200),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: onMarkDone,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.orange500,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text(
                  'Mark Done',
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
