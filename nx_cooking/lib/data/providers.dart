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
final recipeListProvider = FutureProvider<List<RecipeSummary>>(
  (ref) => ref.watch(recipeRepositoryProvider).fetchRecipes(),
);

/// One recipe (detail screen).
final recipeDetailProvider = FutureProvider.family<RecipeDetail?, int>((
  ref,
  id,
) {
  return ref.watch(recipeRepositoryProvider).fetchRecipeDetail(id);
});
