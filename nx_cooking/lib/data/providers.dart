import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/riverpod.dart';
import 'package:nx_cooking/data/fake_cooking_repository.dart';
import 'package:nx_cooking/data/recipe/kgql_recipe_repository.dart';
import 'package:nx_cooking/data/recipe/recipe_schema_provider.dart';
import 'package:nx_cooking/domain/cooking_repository.dart';
import 'package:nx_cooking/domain/recipe.dart';
import 'package:nx_cooking/domain/recipe_detail.dart';
import 'package:nx_cooking/domain/recipe_repository.dart';

export 'package:nx_cooking/data/recipe/recipe_schema_provider.dart';

/// Week / buy / stats (in-memory).
final cookingRepositoryProvider = Provider<CookingRepository>(
  (ref) => FakeCookingRepository(),
);

/// Recipe CRUD via PGDB KGQL.
final recipeRepositoryProvider = Provider<RecipeRepository>(
  (ref) => KgqlRecipeRepository(
    client: ref.watch(graphqlClientProvider),
    loadRecipeSchema: () => ref.read(recipeSchemaProvider.future),
  ),
);

/// Cached list for recipe tab + sub-bar count.
///
/// [IndexedStack] keeps [RecipesPage] built, so this future runs on cold start
/// (not only when the Recipes tab is visible). Stuck loading usually means
/// GraphQL schema load or [fetchKgqlModels] never completed — see debug logs.
final recipeListProvider = FutureProvider<List<RecipeSummary>>((ref) async {
  debugPrint('[nx_cooking:recipeListProvider] start');
  try {
    final list = await ref.watch(recipeRepositoryProvider).fetchRecipes();
    debugPrint(
      '[nx_cooking:recipeListProvider] success count=${list.length}',
    );
    return list;
  } catch (e, st) {
    debugPrint('[nx_cooking:recipeListProvider] caught: $e\n$st');
    rethrow;
  }
});

/// One recipe (detail screen).
final recipeDetailProvider = FutureProvider.family<RecipeDetail?, int>((
  ref,
  id,
) {
  return ref.watch(recipeRepositoryProvider).fetchRecipeDetail(id);
});
