import 'package:nx_cooking/domain/cooking_task_detail.dart';
import 'package:nx_cooking/domain/shopping.dart';
import 'package:nx_cooking/domain/week_section.dart';

/// Week planner + shopping derived from [CookingTask] rows in PGDB.
abstract class CookingPlanRepository {
  Future<List<WeekDaySection>> fetchWeek(DateTime weekStartMonday);

  Future<ShoppingListSnapshot> fetchShopping(DateTime weekStartMonday);

  /// One [CookingTask] by id (nested recipe, items, `ingredient_checks` on `for_recipe`).
  Future<CookingTaskDetail?> fetchTaskDetail(int taskId);

  /// Creates a [CookingTask] with `status: planned` on [date] (local calendar day).
  Future<int> planRecipe({required int recipeId, required DateTime date});

  /// Replaces the JSON map on `for_recipe.ingredient_checks` (keys = item model ids).
  Future<void> updateIngredientChecks(
    int taskId,
    int forRecipeRelationId,
    Map<String, bool> checks,
  );

  /// Deletes the cooking task row.
  Future<void> deleteTask(int taskId);

  /// Moves planned date (local calendar day) on the task.
  Future<void> updateTaskDate(int taskId, DateTime newDate);

  /// Optional [CookingTask.notes] for this planned meal; null/empty clears.
  Future<void> updateTaskNotes(int taskId, String? notes);
}
