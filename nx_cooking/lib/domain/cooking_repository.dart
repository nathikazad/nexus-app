import 'package:nx_cooking/domain/recipe.dart';
import 'package:nx_cooking/domain/recipe_detail.dart';
import 'package:nx_cooking/domain/shopping.dart';
import 'package:nx_cooking/domain/stats.dart';
import 'package:nx_cooking/domain/week_section.dart';

/// Data access for the cooking app. Backed by [FakeCookingRepository] until PGDB
/// wiring exists.
abstract class CookingRepository {
  String get weekRangeLabel;

  List<WeekDaySection> get weekDays;

  List<RecipeSummary> get recipes;

  int get recipeListCount;

  ShoppingListSnapshot get shopping;

  CookingStatsSnapshot get stats;

  RecipeDetail? recipeDetailById(String id);
}
