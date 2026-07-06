import 'package:nx_cooking/domain/cooking_plan_detail.dart';
import 'package:nx_cooking/domain/shopping.dart';
import 'package:nx_cooking/domain/week_section.dart';

/// Week planner + shopping derived from [Cooking] rows with the Plannable mixin.
abstract class CookingPlanRepository {
  Future<List<WeekDaySection>> fetchWeek(DateTime weekStartMonday);

  Future<ShoppingListSnapshot> fetchShopping(DateTime weekStartMonday);

  /// One planned [Cooking] by id (nested recipe, items, `ingredient_checks`).
  Future<CookingPlanDetail?> fetchPlanDetail(int planId);

  /// Creates a planned [Cooking] on [date] (local calendar day).
  Future<int> planRecipe({required int recipeId, required DateTime date});

  /// Replaces the JSON map on `cooks_recipe.ingredient_checks`.
  Future<void> updateIngredientChecks(
    int planId,
    int cooksRecipeRelationId,
    Map<String, bool> checks,
  );

  /// Deletes the planned cooking row.
  Future<void> deletePlan(int planId);

  /// Moves planned date (local calendar day).
  Future<void> updatePlanDate(int planId, DateTime newDate);

  /// Optional description notes for this planned meal; null/empty clears.
  Future<void> updatePlanNotes(int planId, String? notes);
}
