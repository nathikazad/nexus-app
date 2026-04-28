import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nx_cooking/core/layout/layout.dart';
import 'package:nx_cooking/core/theme/app_theme.dart';
import 'package:nx_cooking/data/providers.dart';
import 'package:nx_cooking/data/recipe/import_recipe_api.dart';
import 'package:nx_db/auth.dart';

class RecipesPage extends ConsumerStatefulWidget {
  const RecipesPage({super.key});

  @override
  ConsumerState<RecipesPage> createState() => _RecipesPageState();
}

class _RecipesPageState extends ConsumerState<RecipesPage> {
  bool _importMenuOpen = false;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(recipeListProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Could not load recipes: $e',
            textAlign: TextAlign.center,
          ),
        ),
      ),
      data: (list) => Stack(
        children: [
          if (_importMenuOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _importMenuOpen = false),
                behavior: HitTestBehavior.opaque,
                child: const SizedBox.expand(),
              ),
            ),
          ListView.separated(
            padding: const EdgeInsets.only(
              bottom: CookingLayout.bottomNavExtra + 88,
            ),
            itemCount: list.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: AppColors.zinc100),
            itemBuilder: (context, i) {
              final r = list[i];
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => context.push('/recipe/${r.id}'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.zinc900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          r.metaLine,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.zinc500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          Positioned(
            right: 20,
            bottom: 20 + MediaQuery.paddingOf(context).bottom,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (_importMenuOpen) ...[
                  _FabChoice(label: 'URL', onTap: () {
                    setState(() => _importMenuOpen = false);
                    _showUrlSheet(context);
                  }),
                  const SizedBox(height: 10),
                  _FabChoice(label: 'Note', onTap: () {
                    setState(() => _importMenuOpen = false);
                    _showNoteSheet(context);
                  }),
                  const SizedBox(height: 12),
                ],
                Material(
                  color: AppColors.orange500,
                  borderRadius: BorderRadius.circular(999),
                  elevation: 4,
                  shadowColor: AppColors.orange500.withValues(alpha: 0.25),
                  child: InkWell(
                    onTap: () => setState(() => _importMenuOpen = !_importMenuOpen),
                    customBorder: const CircleBorder(),
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: Icon(
                        _importMenuOpen ? Icons.close : Icons.add,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _importUrl(BuildContext context, String url) async {
    final scaffold = ScaffoldMessenger.of(context);
    scaffold.showSnackBar(
      const SnackBar(
        content: Text('Importing recipe from URL…'),
        duration: Duration(minutes: 5),
      ),
    );
    try {
      final imageBaseUrl = ref.read(imageBaseUrlProvider);
      final userId = ref.read(userIdProvider);
      if (imageBaseUrl == null || userId == null) {
        throw StateError('Not logged in');
      }
      final result = await importRecipeFromUrl(
        imageBaseUrl: imageBaseUrl,
        userId: userId,
        recipeUrl: url,
      );
      scaffold.hideCurrentSnackBar();
      ref.invalidate(recipeListProvider);
      if (context.mounted) {
        context.push('/recipe/${result.recipeId}');
      }
    } catch (e) {
      scaffold.hideCurrentSnackBar();
      scaffold.showSnackBar(
        SnackBar(content: Text('Import failed: $e')),
      );
    }
  }

  Future<void> _importText(BuildContext context, String text) async {
    final scaffold = ScaffoldMessenger.of(context);
    scaffold.showSnackBar(
      const SnackBar(
        content: Text('Importing recipe from text…'),
        duration: Duration(minutes: 5),
      ),
    );
    try {
      final imageBaseUrl = ref.read(imageBaseUrlProvider);
      final userId = ref.read(userIdProvider);
      if (imageBaseUrl == null || userId == null) {
        throw StateError('Not logged in');
      }
      final result = await importRecipeFromPastedText(
        imageBaseUrl: imageBaseUrl,
        userId: userId,
        recipeText: text,
      );
      scaffold.hideCurrentSnackBar();
      ref.invalidate(recipeListProvider);
      if (context.mounted) {
        context.push('/recipe/${result.recipeId}');
      }
    } catch (e) {
      scaffold.hideCurrentSnackBar();
      scaffold.showSnackBar(
        SnackBar(content: Text('Import failed: $e')),
      );
    }
  }

  void _showUrlSheet(BuildContext context) async {
    final url = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (_) => const _UrlSheetBody(),
    );
    if (url != null && url.isNotEmpty && mounted) {
      _importUrl(this.context, url);
    }
  }

  void _showNoteSheet(BuildContext context) async {
    final text = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (_) => const _NoteSheetBody(),
    );
    if (text != null && text.isNotEmpty && mounted) {
      _importText(this.context, text);
    }
  }
}

// ---------------------------------------------------------------------------
// URL bottom sheet (stateful to own its TextEditingController)
// ---------------------------------------------------------------------------

class _UrlSheetBody extends StatefulWidget {
  const _UrlSheetBody();

  @override
  State<_UrlSheetBody> createState() => _UrlSheetBodyState();
}

class _UrlSheetBodyState extends State<_UrlSheetBody> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final url = _controller.text.trim();
    if (url.isEmpty) {
      setState(() => _error = 'Paste a recipe URL first.');
      return;
    }
    Navigator.of(context).pop(url);
  }

  @override
  Widget build(BuildContext context) {
    final inter = GoogleFonts.inter();
    return Padding(
      padding: EdgeInsets.only(
        left: 22,
        right: 22,
        top: 22,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Import from URL',
            style: inter.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              height: 1.15,
              color: AppColors.zinc900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Paste a link to any recipe page.',
            style: inter.copyWith(fontSize: 13, color: AppColors.zinc500),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            style: inter.copyWith(fontSize: 14, color: AppColors.zinc900),
            decoration: InputDecoration(
              hintText: 'https://example.com/my-recipe',
              hintStyle: inter.copyWith(fontSize: 14, color: AppColors.zinc400),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
                borderSide:
                    const BorderSide(color: AppColors.orange500, width: 1.5),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: inter.copyWith(fontSize: 13, color: AppColors.orange700),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.orange500,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: inter.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('Import'),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Note (pasted text) bottom sheet
// ---------------------------------------------------------------------------

class _NoteSheetBody extends StatefulWidget {
  const _NoteSheetBody();

  @override
  State<_NoteSheetBody> createState() => _NoteSheetBodyState();
}

class _NoteSheetBodyState extends State<_NoteSheetBody> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Paste the recipe text first.');
      return;
    }
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    final inter = GoogleFonts.inter();
    return FractionallySizedBox(
      heightFactor: 0.86,
      child: Padding(
        padding: EdgeInsets.only(
          left: 22,
          right: 22,
          top: 22,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Import from note',
              style: inter.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                height: 1.15,
                color: AppColors.zinc900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Paste the full recipe — ingredients, instructions, etc.',
              style: inter.copyWith(fontSize: 13, color: AppColors.zinc500),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: TextField(
                controller: _controller,
                autofocus: true,
                expands: true,
                minLines: null,
                maxLines: null,
                textAlignVertical: TextAlignVertical.top,
                style: inter.copyWith(fontSize: 14, color: AppColors.zinc900),
                decoration: InputDecoration(
                  hintText: 'Chocolate Cake\n\nIngredients:\n2 cups flour\n...',
                  hintStyle:
                      inter.copyWith(fontSize: 14, color: AppColors.zinc400),
                  alignLabelWithHint: true,
                  contentPadding: const EdgeInsets.all(14),
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
                        color: AppColors.orange500, width: 1.5),
                  ),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style:
                    inter.copyWith(fontSize: 13, color: AppColors.orange700),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.orange500,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: inter.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('Import'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// FAB choice pill
// ---------------------------------------------------------------------------

class _FabChoice extends StatelessWidget {
  const _FabChoice({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(999),
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.zinc800,
            ),
          ),
        ),
      ),
    );
  }
}
