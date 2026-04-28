import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nx_cooking/core/theme/app_theme.dart';
import 'package:nx_cooking/data/providers.dart';
import 'package:nx_cooking/domain/recipe_detail.dart';
import 'package:nx_cooking/domain/schema/model_type_view.dart';
import 'package:nx_cooking/features/recipe_edit/widgets/tag_picker.dart';
import 'package:solar_icon_pack/solar_icon_pack.dart';

/// Edit recipe name and tag assignments; delete recipe.
class RecipeEditPage extends ConsumerWidget {
  const RecipeEditPage({super.key, required this.recipeId});

  final int recipeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(recipeDetailProvider(recipeId));
    final schemaAsync = ref.watch(recipeSchemaViewProvider);

    return detailAsync.when(
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
        body: Center(child: Text('Error: $e')),
      ),
      data: (RecipeDetail? detail) {
        if (detail == null) {
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(SolarLinearIcons.altArrowLeft, size: 22),
                onPressed: () => context.pop(),
              ),
              title: const Text('Recipe'),
            ),
            body: const Center(child: Text('Recipe not found')),
          );
        }
        return schemaAsync.when(
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
            body: Center(child: Text('Error: $e')),
          ),
          data: (ModelTypeView? schema) {
            if (schema == null) {
              return Scaffold(
                appBar: AppBar(
                  leading: IconButton(
                    icon: const Icon(SolarLinearIcons.altArrowLeft, size: 22),
                    onPressed: () => context.pop(),
                  ),
                ),
                body: const Center(child: Text('Schema unavailable')),
              );
            }
            return _RecipeEditForm(
              key: ValueKey(detail.id),
              detail: detail,
              schema: schema,
              recipeId: recipeId,
            );
          },
        );
      },
    );
  }
}

class _RecipeEditForm extends ConsumerStatefulWidget {
  const _RecipeEditForm({
    super.key,
    required this.detail,
    required this.schema,
    required this.recipeId,
  });

  final RecipeDetail detail;
  final ModelTypeView schema;
  final int recipeId;

  @override
  ConsumerState<_RecipeEditForm> createState() => _RecipeEditFormState();
}

class _RecipeEditFormState extends ConsumerState<_RecipeEditForm> {
  late final TextEditingController _name;
  late Map<String, List<String>> _tags;
  bool _saving = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.detail.title);
    _tags = {
      for (final s in widget.schema.tagSystems)
        s.name: List<String>.from(
          widget.detail.tagsMap[s.name] ?? const <String>[],
        ),
    };
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Map<String, List<String>> _tagsForSave() {
    return {
      for (final s in widget.schema.tagSystems)
        s.name: List<String>.from(_tags[s.name] ?? const <String>[]),
    };
  }

  Future<void> _onSave() async {
    if (_saving) {
      return;
    }
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(recipeRepositoryProvider).updateRecipeMeta(
            widget.recipeId,
            _name.text,
            _tagsForSave(),
          );
      ref.invalidate(recipeDetailProvider(widget.recipeId));
      ref.invalidate(recipeListProvider);
      messenger.showSnackBar(const SnackBar(content: Text('Saved')));
      if (mounted) {
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _onDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete recipe?'),
        content: const Text(
          'This cannot be undone. The recipe will be removed from your collection.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!mounted) {
      return;
    }
    if (ok != true || _deleting) {
      return;
    }
    setState(() => _deleting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(recipeRepositoryProvider).deleteRecipe(widget.recipeId);
      ref.invalidate(recipeDetailProvider(widget.recipeId));
      ref.invalidate(recipeListProvider);
      messenger.showSnackBar(const SnackBar(content: Text('Recipe deleted')));
      if (mounted) {
        context.go('/');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _deleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final systems = widget.schema.tagSystems;

    return Scaffold(
      backgroundColor: AppColors.zinc50,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(SolarLinearIcons.altArrowLeft, size: 22),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Edit recipe',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.zinc900,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_saving)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(right: 16),
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _onSave,
              child: Text(
                'Save',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.orange500,
                ),
              ),
            ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.zinc100),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: [
          Text(
            'Name',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.zinc500,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            style: GoogleFonts.inter(
              fontSize: 16,
              color: AppColors.zinc900,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.zinc200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.zinc200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.orange500, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Tags',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.zinc500,
            ),
          ),
          const SizedBox(height: 12),
          if (systems.isEmpty)
            Text(
              'No tag systems',
              style: GoogleFonts.inter(fontSize: 14, color: AppColors.zinc400),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.zinc100),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < systems.length; i++) ...[
                    TagPickerRow(
                      system: systems[i],
                      value: _tags[systems[i].name] ?? const [],
                      onChanged: (v) => setState(
                        () => _tags[systems[i].name] = v,
                      ),
                    ),
                    if (i < systems.length - 1)
                      const Divider(height: 1, color: AppColors.zinc100),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 40),
          OutlinedButton(
            onPressed: _deleting ? null : _onDelete,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _deleting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.red,
                    ),
                  )
                : Text(
                    'Delete recipe',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
