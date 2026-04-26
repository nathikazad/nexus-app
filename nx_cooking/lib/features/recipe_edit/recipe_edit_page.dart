import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nx_cooking/core/theme/app_theme.dart';
import 'package:nx_cooking/data/providers.dart';
import 'package:nx_cooking/domain/recipe_detail.dart';
import 'package:solar_icon_pack/solar_icon_pack.dart';

class RecipeEditPage extends ConsumerWidget {
  const RecipeEditPage({super.key, required this.recipeId});

  final int recipeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(recipeDetailProvider(recipeId));
    return async.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(
          title: const Text('Edit'),
          leading: IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(SolarLinearIcons.altArrowLeft, size: 22),
          ),
        ),
        body: Center(child: Text('$e')),
      ),
      data: (RecipeDetail? d) {
        if (d == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Edit'),
              leading: IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(SolarLinearIcons.altArrowLeft, size: 22),
              ),
            ),
            body: const Center(child: Text('Recipe not found')),
          );
        }
        return RecipeFormPage(
          key: ObjectKey('edit-$recipeId'),
          initial: RecipeFormData.fromDetail(d),
          isCreate: false,
          recipeId: recipeId,
        );
      },
    );
  }
}

class RecipeFormPage extends ConsumerStatefulWidget {
  const RecipeFormPage({
    super.key,
    required this.initial,
    required this.isCreate,
    this.recipeId,
  });

  final RecipeFormData initial;
  final bool isCreate;
  final int? recipeId;

  @override
  ConsumerState<RecipeFormPage> createState() => _RecipeFormPageState();
}

class _RecipeFormPageState extends ConsumerState<RecipeFormPage> {
  late RecipeFormData _form;
  final _tagController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _form = _cloneForm(widget.initial);
  }

  RecipeFormData _cloneForm(RecipeFormData s) {
    return RecipeFormData(
      name: s.name,
      tags: List<String>.from(s.tags),
      prepTimeMinutesText: s.prepTimeMinutesText,
      servingsText: s.servingsText,
      notes: s.notes,
      ingredients: s.ingredients
          .map(
            (e) => RecipeIngredientFormLine(
              relationId: e.relationId,
              itemId: e.itemId,
              name: e.name,
              quantityText: e.quantityText,
              unit: e.unit,
            ),
          )
          .toList(),
      instructionSteps: List<String>.from(s.instructionSteps),
    );
  }

  Future<void> _onSave() async {
    if (_form.name.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Name is required')));
      return;
    }
    setState(() => _saving = true);
    try {
      final repo = ref.read(recipeRepositoryProvider);
      if (widget.isCreate) {
        final newId = await repo.createRecipe(_form);
        ref.invalidate(recipeListProvider);
        ref.invalidate(recipeDetailProvider(newId));
        if (mounted) {
          context.go('/recipe/$newId');
        }
      } else {
        final id = widget.recipeId!;
        await repo.updateRecipe(id, _form);
        ref.invalidate(recipeListProvider);
        ref.invalidate(recipeDetailProvider(id));
        if (mounted) {
          context.pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _onDelete() async {
    final id = widget.recipeId;
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete recipe?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.zinc500),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await ref.read(recipeRepositoryProvider).deleteRecipe(id);
      if (!mounted) return;
      ref.invalidate(recipeListProvider);
      ref.invalidate(recipeDetailProvider(id));
      context.go('/');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  void dispose() {
    _tagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isCreate ? 'New Recipe' : 'Edit Recipe'),
        leading: IconButton(
          icon: const Icon(SolarLinearIcons.altArrowLeft, size: 22),
          onPressed: _saving ? null : () => context.pop(),
        ),
        actions: [
          if (!_saving)
            TextButton(
              onPressed: _onSave,
              child: const Text(
                'Save',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          const Text(
            'NAME',
            style: TextStyle(
              fontSize: 10.4,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: AppColors.zinc400,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            initialValue: _form.name,
            onChanged: (v) => _form.name = v,
            decoration: _inputDecoration('Recipe name'),
          ),
          const SizedBox(height: 20),
          const Text(
            'TAGS',
            style: TextStyle(
              fontSize: 10.4,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: AppColors.zinc400,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ..._form.tags.map(
                (t) => InputChip(
                  label: Text(t),
                  onDeleted: () => setState(() => _form.tags.remove(t)),
                ),
              ),
              SizedBox(
                width: 120,
                child: TextField(
                  controller: _tagController,
                  decoration: _inputDecoration('Add'),
                  onSubmitted: (v) {
                    if (v.trim().isNotEmpty) {
                      setState(() {
                        _form.tags.add(v.trim());
                        _tagController.clear();
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PREP (MIN)',
                      style: TextStyle(
                        fontSize: 10.4,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                        color: AppColors.zinc400,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      initialValue: _form.prepTimeMinutesText,
                      onChanged: (v) => _form.prepTimeMinutesText = v,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration('e.g. 30'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SERVINGS',
                      style: TextStyle(
                        fontSize: 10.4,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                        color: AppColors.zinc400,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      initialValue: _form.servingsText,
                      onChanged: (v) => _form.servingsText = v,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration('e.g. 4'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'INGREDIENTS',
            style: TextStyle(
              fontSize: 10.4,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: AppColors.zinc400,
            ),
          ),
          const SizedBox(height: 6),
          ...List.generate(_form.ingredients.length, (i) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      initialValue: _form.ingredients[i].name,
                      onChanged: (v) => _form.ingredients[i].name = v,
                      decoration: _inputDecoration('Ingredient'),
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 56,
                    child: TextFormField(
                      initialValue: _form.ingredients[i].quantityText,
                      onChanged: (v) => _form.ingredients[i].quantityText = v,
                      decoration: _inputDecoration('Qty'),
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 52,
                    child: TextFormField(
                      initialValue: _form.ingredients[i].unit,
                      onChanged: (v) => _form.ingredients[i].unit = v,
                      decoration: _inputDecoration('Unit'),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      SolarLinearIcons.closeCircle,
                      size: 20,
                      color: AppColors.zinc300,
                    ),
                    onPressed: () {
                      setState(() {
                        if (_form.ingredients.length > 1) {
                          _form.ingredients.removeAt(i);
                        }
                      });
                    },
                  ),
                ],
              ),
            );
          }),
          OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _form.ingredients.add(
                  RecipeIngredientFormLine(
                    name: '',
                    quantityText: '',
                    unit: '',
                  ),
                );
              });
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.zinc400,
              side: const BorderSide(
                color: AppColors.zinc300,
                style: BorderStyle.solid,
              ),
            ),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add ingredient'),
          ),
          const SizedBox(height: 20),
          const Text(
            'INSTRUCTIONS',
            style: TextStyle(
              fontSize: 10.4,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: AppColors.zinc400,
            ),
          ),
          const SizedBox(height: 6),
          ...List.generate(_form.instructionSteps.length, (i) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      '${i + 1}.',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.orange500,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      initialValue: _form.instructionSteps[i],
                      onChanged: (v) => _form.instructionSteps[i] = v,
                      minLines: 1,
                      maxLines: 4,
                      decoration: _inputDecoration('Step'),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      SolarLinearIcons.closeCircle,
                      size: 20,
                      color: AppColors.zinc300,
                    ),
                    onPressed: () {
                      setState(() {
                        if (_form.instructionSteps.length > 1) {
                          _form.instructionSteps.removeAt(i);
                        }
                      });
                    },
                  ),
                ],
              ),
            );
          }),
          OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _form.instructionSteps.add('');
              });
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.zinc400,
              side: const BorderSide(
                color: AppColors.zinc300,
                style: BorderStyle.solid,
              ),
            ),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add step'),
          ),
          const SizedBox(height: 20),
          const Text(
            'NOTES',
            style: TextStyle(
              fontSize: 10.4,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: AppColors.zinc400,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            initialValue: _form.notes,
            onChanged: (v) => _form.notes = v,
            minLines: 3,
            maxLines: 5,
            decoration: _inputDecoration('Optional notes'),
          ),
          if (!widget.isCreate) ...[
            const SizedBox(height: 28),
            OutlinedButton.icon(
              onPressed: _saving ? null : _onDelete,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: AppColors.zinc200),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(SolarLinearIcons.trashBin, size: 16),
              label: const Text('Delete recipe'),
            ),
          ],
        ],
      ),
    );
  }
}

InputDecoration _inputDecoration(String hint) {
  return InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: AppColors.zinc50,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
      borderSide: const BorderSide(color: AppColors.orange500, width: 1.2),
    ),
  );
}
