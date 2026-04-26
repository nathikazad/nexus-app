import 'package:nx_cooking/domain/recipe.dart';
import 'package:nx_cooking/domain/recipe_detail.dart';

/// Recipe CRUD backed by PGDB KGQL (`Recipe`, `Item`, `has_ingredient`).
abstract class RecipeRepository {
  Future<List<RecipeSummary>> fetchRecipes();

  Future<RecipeDetail?> fetchRecipeDetail(int id);

  Future<int> createRecipe(RecipeFormData form);

  Future<void> updateRecipe(int id, RecipeFormData form);

  Future<void> deleteRecipe(int id);
}
