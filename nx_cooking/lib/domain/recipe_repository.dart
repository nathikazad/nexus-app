import 'package:nx_cooking/domain/recipe.dart';
import 'package:nx_cooking/domain/recipe_detail.dart';
import 'package:nx_cooking/domain/recipe_filter.dart';
import 'package:nx_cooking/domain/search_result.dart';

/// Recipe CRUD backed by PGDB KGQL (`Recipe`, `Item`, `has_ingredient`).
abstract class RecipeRepository {
  Future<List<RecipeSummary>> fetchRecipes({RecipeFilter? filter});

  /// Fuzzy search (`app.search_recipes`) across recipes, cooking items, tags.
  Future<List<RecipeSearchResult>> searchRecipes(String term, {int limitPer = 10});

  Future<RecipeDetail?> fetchRecipeDetail(int id);

  Future<int> createRecipe(RecipeFormData form);

  Future<void> updateRecipe(int id, RecipeFormData form);

  /// Update display name and tag assignments only (no ingredients/instructions).
  Future<void> updateRecipeMeta(int id, String name, Map<String, List<String>> tags);

  Future<void> deleteRecipe(int id);
}
