import 'package:nx_cooking/domain/recipe.dart';
import 'package:nx_cooking/domain/recipe_detail.dart';
import 'package:nx_cooking/domain/recipe_repository.dart';

/// Local demo [RecipeRepository] (no GraphQL) — use in tests or offline.
final class FakeRecipeRepository implements RecipeRepository {
  @override
  Future<List<RecipeSummary>> fetchRecipes() async {
    return const [
      RecipeSummary(
        id: '1',
        title: 'Spicy Garlic Noodles',
        metaLine: '4 ingredients · Cooked 2d ago',
        tags: ['Asian', 'Quick'],
        ingredientCount: 4,
        prepTimeMinutes: 25,
      ),
      RecipeSummary(
        id: '2',
        title: 'Roasted Salmon',
        metaLine: '6 ingredients · Never cooked',
        tags: ['Healthy'],
        ingredientCount: 6,
        prepTimeMinutes: 40,
      ),
      RecipeSummary(
        id: '3',
        title: 'Matcha Pancakes',
        metaLine: '8 ingredients · Cooked 1w ago',
        tags: ['Breakfast'],
        ingredientCount: 8,
        prepTimeMinutes: 20,
      ),
      RecipeSummary(
        id: '4',
        title: 'Classic Beef Stew',
        metaLine: '12 ingredients · Cooked 3d ago',
        tags: ['Slow'],
        ingredientCount: 12,
        prepTimeMinutes: 180,
      ),
    ];
  }

  @override
  Future<RecipeDetail?> fetchRecipeDetail(int id) async {
    if (id == 1) {
      return const RecipeDetail(
        id: 1,
        title: 'Spicy Garlic Sesame Noodles',
        tags: ['Asian', 'Quick'],
        prepTimeMinutes: 25,
        servings: 2,
        notes: 'Works great with soba too.',
        lastCookedLabel: 'Cooked 2d ago',
        headerLine: 'Monday, Oct 16 · Started 6:15 PM',
        statusChip: 'Cooking',
        ingredients: [
          IngredientLine(
            name: 'Udon noodles',
            amount: '200 g',
            initialChecked: true,
            itemId: 100,
            relationId: 200,
          ),
          IngredientLine(
            name: 'Garlic cloves',
            amount: '3',
            initialChecked: true,
            itemId: 101,
            relationId: 201,
          ),
          IngredientLine(
            name: 'Chili oil',
            amount: '2 tbsp',
            initialChecked: false,
            itemId: 102,
            relationId: 202,
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
    if (id == 2) {
      return const RecipeDetail(
        id: 2,
        title: 'Roasted Salmon',
        tags: ['Healthy'],
        prepTimeMinutes: 40,
        servings: 2,
        notes: null,
        ingredients: [],
        instructionLines: [
          'Preheat oven. Season salmon.',
          'Roast with asparagus until done.',
        ],
      );
    }
    if (id == 3) {
      return const RecipeDetail(
        id: 3,
        title: 'Matcha Pancakes',
        tags: ['Breakfast'],
        prepTimeMinutes: 20,
        servings: 4,
        notes: null,
        ingredients: [],
        instructionLines: ['Mix dry and wet. Cook on griddle.'],
      );
    }
    if (id == 4) {
      return const RecipeDetail(
        id: 4,
        title: 'Classic Beef Stew',
        tags: ['Slow'],
        prepTimeMinutes: 180,
        servings: 6,
        notes: null,
        ingredients: [],
        instructionLines: ['Brown meat.', 'Simmer for hours.'],
      );
    }
    return null;
  }

  @override
  Future<int> createRecipe(RecipeFormData form) async {
    return 999;
  }

  @override
  Future<void> updateRecipe(int id, RecipeFormData form) async {}

  @override
  Future<void> deleteRecipe(int id) async {}
}
