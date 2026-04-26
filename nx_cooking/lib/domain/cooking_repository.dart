import 'package:nx_cooking/domain/shopping.dart';
import 'package:nx_cooking/domain/stats.dart';
import 'package:nx_cooking/domain/week_section.dart';

/// Data for shell tabs (week, buy, stats). Recipe lists use [RecipeRepository].
abstract class CookingRepository {
  String get weekRangeLabel;

  List<WeekDaySection> get weekDays;

  ShoppingListSnapshot get shopping;

  CookingStatsSnapshot get stats;
}
