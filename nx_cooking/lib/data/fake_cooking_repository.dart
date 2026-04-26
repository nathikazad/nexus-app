import 'package:nx_cooking/domain/cooking_repository.dart';
import 'package:nx_cooking/domain/meal_status.dart';
import 'package:nx_cooking/domain/recipe.dart';
import 'package:nx_cooking/domain/recipe_detail.dart';
import 'package:nx_cooking/domain/shopping.dart';
import 'package:nx_cooking/domain/stats.dart';
import 'package:nx_cooking/domain/week_section.dart';

/// In-memory data matching `reference/index.html` (no network).
final class FakeCookingRepository implements CookingRepository {
  FakeCookingRepository();

  static const _spicyGarlicId = 'spicy-garlic-sesame-noodles';

  @override
  String get weekRangeLabel => 'Oct 16 – 22';

  @override
  int get recipeListCount => 64;

  @override
  List<WeekDaySection> get weekDays => const [
    WeekDaySection(
      dayLabel: 'Monday, Oct 16',
      isToday: true,
      meal: WeekMealCard(
        id: _spicyGarlicId,
        title: 'Spicy Garlic Sesame Noodles',
        kind: MealCardKind.cookingInProgress,
        badge: '3/4 steps',
        subtitle: 'Cooking in progress',
        showPing: true,
      ),
    ),
    WeekDaySection(
      dayLabel: 'Tuesday, Oct 17',
      isToday: false,
      meal: WeekMealCard(
        id: 'roasted-salmon',
        title: 'Roasted Salmon & Asparagus',
        kind: MealCardKind.planned,
        badge: '0/6 items',
        subtitle: 'Needs shopping',
        showPing: false,
      ),
    ),
    WeekDaySection(
      dayLabel: 'Sunday, Oct 15',
      isToday: false,
      meal: WeekMealCard(
        id: 'classic-beef-stew',
        title: 'Classic Beef Stew',
        kind: MealCardKind.done,
        badge: '',
        subtitle: 'Cooked · 2h 15m',
        showPing: false,
      ),
    ),
  ];

  @override
  List<RecipeSummary> get recipes => const [
    RecipeSummary(
      id: 'spicy-garlic-noodles',
      title: 'Spicy Garlic Noodles',
      metaLine: '4 ingredients · Cooked 2d ago',
      tags: ['Asian', 'Quick'],
    ),
    RecipeSummary(
      id: 'roasted-salmon',
      title: 'Roasted Salmon',
      metaLine: '6 ingredients · Never cooked',
      tags: ['Healthy'],
    ),
    RecipeSummary(
      id: 'matcha-pancakes',
      title: 'Matcha Pancakes',
      metaLine: '8 ingredients · Cooked 1w ago',
      tags: ['Breakfast'],
    ),
    RecipeSummary(
      id: 'classic-beef-stew',
      title: 'Classic Beef Stew',
      metaLine: '12 ingredients · Cooked 3d ago',
      tags: ['Slow'],
    ),
  ];

  @override
  ShoppingListSnapshot get shopping => const ShoppingListSnapshot(
    purchasedCount: 3,
    totalCount: 10,
    groups: [
      ShoppingMealGroup(
        header: 'Mon 16 · Spicy Garlic Noodles',
        items: [
          ShoppingItem(
            name: 'Udon noodles',
            amount: '200 g',
            initialChecked: true,
          ),
          ShoppingItem(
            name: 'Garlic cloves',
            amount: '3',
            initialChecked: false,
          ),
          ShoppingItem(
            name: 'Chili oil',
            amount: '2 tbsp',
            initialChecked: false,
          ),
        ],
      ),
      ShoppingMealGroup(
        header: 'Tue 17 · Roasted Salmon & Asparagus',
        items: [
          ShoppingItem(
            name: 'Salmon fillets',
            amount: '2 (150g each)',
            initialChecked: false,
          ),
          ShoppingItem(
            name: 'Asparagus',
            amount: '1 bunch',
            initialChecked: false,
          ),
          ShoppingItem(name: 'Lemon', amount: '1', initialChecked: false),
        ],
      ),
    ],
  );

  @override
  CookingStatsSnapshot get stats => const CookingStatsSnapshot(
    mealsCooked: '2',
    totalTimeLabel: '3h 10m',
    cookedThisWeek: [
      StatMealRow(
        title: 'Classic Beef Stew',
        whenLabel: 'Sunday',
        durationLabel: '2h 15m',
      ),
      StatMealRow(
        title: 'Omelette',
        whenLabel: 'Monday morning',
        durationLabel: '15m',
      ),
    ],
  );

  @override
  RecipeDetail? recipeDetailById(String id) {
    if (id == _spicyGarlicId || id == 'spicy-garlic-noodles') {
      return const RecipeDetail(
        id: _spicyGarlicId,
        title: 'Spicy Garlic Sesame Noodles',
        headerLine: 'Monday, Oct 16 · Started 6:15 PM',
        statusChip: 'Cooking',
        ingredients: [
          IngredientLine(
            name: 'Udon noodles',
            amount: '200 g',
            initialChecked: true,
          ),
          IngredientLine(
            name: 'Garlic cloves',
            amount: '3',
            initialChecked: true,
          ),
          IngredientLine(
            name: 'Chili oil',
            amount: '2 tbsp',
            initialChecked: false,
          ),
        ],
        instructionLines: [
          'Boil water and cook udon noodles according to package instructions. Drain and set aside.',
          'Mince the garlic cloves finely.',
          'Heat a pan, add chili oil and minced garlic. Sauté for 1 minute until fragrant.',
          'Toss the cooked noodles in the garlic oil until well coated. Serve immediately.',
        ],
      );
    }
    return null;
  }
}
