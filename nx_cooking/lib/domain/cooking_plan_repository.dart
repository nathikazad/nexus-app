import 'package:nx_cooking/domain/shopping.dart';
import 'package:nx_cooking/domain/week_section.dart';

/// Week planner + shopping derived from [CookingTask] rows in PGDB.
abstract class CookingPlanRepository {
  Future<List<WeekDaySection>> fetchWeek(DateTime weekStartMonday);

  Future<ShoppingListSnapshot> fetchShopping(DateTime weekStartMonday);

  /// Creates a [CookingTask] with `status: planned` on [date] (local calendar day).
  Future<int> planRecipe({required int recipeId, required DateTime date});
}
