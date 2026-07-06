import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:nx_cooking/core/dates/week_calendar.dart';
import 'package:nx_cooking/core/theme/app_theme.dart';
import 'package:nx_cooking/data/providers.dart';
import 'package:nx_cooking/domain/cooking_plan_detail.dart';
import 'package:solar_icon_pack/solar_icon_pack.dart';

/// Planned meal: recipe, planned date, ingredient checks (persisted), instructions, reschedule / delete.
class CookingPlanViewPage extends ConsumerWidget {
  const CookingPlanViewPage({super.key, required this.planId});

  final int planId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _CookingPlanBody(planId: planId);
  }
}

class _CookingPlanBody extends ConsumerWidget {
  const _CookingPlanBody({required this.planId});

  final int planId;

  Future<void> _toggleIngredient(
    BuildContext context,
    WidgetRef ref,
    int index,
    bool value,
    CookingPlanDetail d,
  ) async {
    if (d.planRecipeRelationId == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update (missing link data).')),
      );
      return;
    }
    final m = <String, bool>{};
    for (var j = 0; j < d.ingredients.length; j++) {
      m['${d.ingredients[j].itemId}'] = j == index
          ? value
          : d.ingredients[j].checked;
    }
    try {
      await ref
          .read(cookingPlanRepositoryProvider)
          .updateIngredientChecks(d.planId, d.planRecipeRelationId, m);
      ref.invalidate(cookingPlanDetailProvider(planId));
      ref.invalidate(weekSectionsProvider);
      ref.invalidate(shoppingSnapshotProvider);
    } catch (e) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save: $e')));
    }
  }

  Future<void> _pickDate(
    BuildContext context,
    WidgetRef ref,
    CookingPlanDetail d,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: dateOnly(d.plannedDate),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.orange500,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.zinc900,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null || !context.mounted) {
      return;
    }
    try {
      await ref
          .read(cookingPlanRepositoryProvider)
          .updatePlanDate(d.planId, picked);
      ref.read(selectedWeekStartProvider.notifier).setToContaining(picked);
      ref.invalidate(cookingPlanDetailProvider(planId));
      ref.invalidate(weekSectionsProvider);
      ref.invalidate(shoppingSnapshotProvider);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Moved to ${DateFormat.yMMMd().format(picked)}'),
        ),
      );
    } catch (e) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not update date: $e')));
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    CookingPlanDetail d,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove from plan?'),
        content: const Text(
          'This removes the planned cooking session. The recipe is not deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.orange500),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) {
      return;
    }
    try {
      await ref.read(cookingPlanRepositoryProvider).deletePlan(d.planId);
      ref.invalidate(weekSectionsProvider);
      ref.invalidate(shoppingSnapshotProvider);
      if (!context.mounted) {
        return;
      }
      context.pop();
    } catch (e) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not delete: $e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncD = ref.watch(cookingPlanDetailProvider(planId));
    return asyncD.when(
      data: (d) {
        if (d == null) {
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(SolarLinearIcons.altArrowLeft, size: 22),
                onPressed: () => context.pop(),
              ),
            ),
            body: const Center(child: Text('Planned meal not found')),
          );
        }
        return Scaffold(
          backgroundColor: Colors.white,
          body: Column(
            children: [
              _TopBar(
                onBack: () => context.pop(),
                onDelete: () => _confirmDelete(context, ref, d),
              ),
              const Divider(height: 1, color: AppColors.orange100),
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(child: _Header(detail: d)),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(22, 8, 22, 120),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _IngredientsChecklist(
                            detail: d,
                            onToggle: (i, v) =>
                                _toggleIngredient(context, ref, i, v, d),
                          ),
                          const SizedBox(height: 28),
                          _InstructionsBlock(lines: d.instructionLines),
                          const SizedBox(height: 28),
                          _PlanNotesSection(
                            planId: d.planId,
                            initialNotes: d.notes,
                          ),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: _Footer(
            onChangeDate: () => _pickDate(context, ref, d),
            onDelete: () => _confirmDelete(context, ref, d),
          ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(SolarLinearIcons.altArrowLeft, size: 22),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
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
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack, required this.onDelete});

  final VoidCallback onBack;
  final VoidCallback onDelete;

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
                'Planned meal',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.zinc900,
                ),
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'delete') {
                  onDelete();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete planned meal'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.detail});

  final CookingPlanDetail detail;

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
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _DateChip(
                text: DateFormat('EEE, MMM d').format(detail.plannedDate),
              ),
              if (detail.status == 'attended')
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.zinc100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'cooked',
                    style: const TextStyle(
                      fontSize: 9.6,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: AppColors.zinc600,
                    ),
                  ),
                ),
            ],
          ),
          if (detail.tags.isNotEmpty) ...[
            const SizedBox(height: 12),
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
          ],
          if (detail.tags.isNotEmpty) const SizedBox(height: 12),
          Text(
            detail.recipeName,
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

class _DateChip extends StatelessWidget {
  const _DateChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.orange100.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: AppColors.orange800,
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.detail});

  final CookingPlanDetail detail;

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
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    return Wrap(spacing: 16, runSpacing: 4, children: items);
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

class _IngredientsChecklist extends StatelessWidget {
  const _IngredientsChecklist({required this.detail, required this.onToggle});

  final CookingPlanDetail detail;
  final void Function(int index, bool value) onToggle;

  @override
  Widget build(BuildContext context) {
    if (detail.ingredients.isEmpty) {
      return const Text(
        'No ingredients on this recipe.',
        style: TextStyle(color: AppColors.zinc500),
      );
    }
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
                _IngredientCheckRow(
                  name: detail.ingredients[i].name,
                  amount: detail.ingredients[i].amount,
                  groupName: detail.ingredients[i].groupName,
                  preparation: detail.ingredients[i].preparation,
                  checked: detail.ingredients[i].checked,
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

class _IngredientCheckRow extends StatelessWidget {
  const _IngredientCheckRow({
    required this.name,
    required this.amount,
    this.groupName,
    this.preparation,
    required this.checked,
    required this.onChanged,
  });

  final String name;
  final String amount;
  final String? groupName;
  final String? preparation;
  final bool checked;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: checked ? AppColors.zinc50 : Colors.white,
      child: InkWell(
        onTap: () => onChanged(!checked),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (groupName != null && groupName!.trim().isNotEmpty)
                      Text(
                        groupName!.trim(),
                        style: TextStyle(
                          fontSize: 10.4,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4,
                          color: checked
                              ? AppColors.zinc400
                              : AppColors.zinc500,
                        ),
                      ),
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: checked ? AppColors.zinc400 : AppColors.zinc900,
                        decoration: checked ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    if (preparation != null && preparation!.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          preparation!.trim(),
                          style: TextStyle(
                            fontSize: 12,
                            color: checked
                                ? AppColors.zinc400
                                : AppColors.zinc500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (amount.isNotEmpty)
                Text(
                  amount,
                  style: TextStyle(
                    fontSize: 12,
                    color: checked ? AppColors.zinc400 : AppColors.zinc400,
                  ),
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

class _PlanNotesSection extends ConsumerStatefulWidget {
  const _PlanNotesSection({required this.planId, required this.initialNotes});

  final int planId;
  final String? initialNotes;

  @override
  ConsumerState<_PlanNotesSection> createState() => _PlanNotesSectionState();
}

class _PlanNotesSectionState extends ConsumerState<_PlanNotesSection> {
  late final TextEditingController _controller;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialNotes ?? '');
  }

  @override
  void didUpdateWidget(covariant _PlanNotesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_dirty && oldWidget.initialNotes != widget.initialNotes) {
      _controller.text = widget.initialNotes ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final trimmed = _controller.text.trim();
    try {
      await ref
          .read(cookingPlanRepositoryProvider)
          .updatePlanNotes(widget.planId, trimmed.isEmpty ? null : trimmed);
      if (!mounted) {
        return;
      }
      ref.invalidate(cookingPlanDetailProvider(widget.planId));
      setState(() => _dirty = false);
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save note: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'YOUR NOTES',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
            color: AppColors.zinc400,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _controller,
          minLines: 3,
          maxLines: 8,
          onChanged: (_) {
            if (!_dirty) {
              setState(() => _dirty = true);
            }
          },
          style: const TextStyle(
            fontSize: 14,
            height: 1.45,
            color: AppColors.zinc700,
          ),
          decoration: InputDecoration(
            hintText: 'Notes for this planned meal only…',
            hintStyle: const TextStyle(color: AppColors.zinc400),
            filled: true,
            fillColor: AppColors.zinc50,
            contentPadding: const EdgeInsets.all(14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.zinc200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.zinc200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: AppColors.orange500,
                width: 1.2,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.tonal(
            onPressed: _dirty ? _save : null,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.orange100,
              foregroundColor: AppColors.orange800,
            ),
            child: const Text(
              'Save note',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.onChangeDate, required this.onDelete});

  final VoidCallback onChangeDate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.95),
      elevation: 8,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.orange100)),
        ),
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(18, 12, 18, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onChangeDate,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.zinc700,
                    side: const BorderSide(color: AppColors.zinc200),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(SolarLinearIcons.calendar, size: 16),
                  label: const Text(
                    'Change date',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: onDelete,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.zinc600,
                    side: const BorderSide(color: AppColors.zinc200),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'Delete',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
