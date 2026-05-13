import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/kgql.dart';
import 'package:nx_db/person.dart';
import 'package:nx_db/riverpod.dart';
import 'package:nx_cooking/core/dates/week_calendar.dart';
import 'package:nx_cooking/data/cooking_task/cooking_task_schema_provider.dart';
import 'package:nx_cooking/data/cooking_task/kgql_cooking_plan_repository.dart';
import 'package:nx_cooking/data/fake_cooking_repository.dart';
import 'package:nx_cooking/data/recipe/kgql_recipe_repository.dart';
import 'package:nx_cooking/data/recipe/recipe_schema_provider.dart';
import 'package:nx_cooking/data/schema/model_type_view_mapper.dart';
import 'package:nx_cooking/domain/cooking_plan_repository.dart';
import 'package:nx_cooking/domain/cooking_repository.dart';
import 'package:nx_cooking/domain/cooking_task_detail.dart';
import 'package:nx_cooking/domain/recipe.dart';
import 'package:nx_cooking/domain/recipe_detail.dart';
import 'package:nx_cooking/domain/recipe_filter.dart';
import 'package:nx_cooking/domain/recipe_repository.dart';
import 'package:nx_cooking/domain/schema/model_type_view.dart';
import 'package:nx_cooking/domain/search_result.dart';
import 'package:nx_cooking/domain/shopping.dart';
import 'package:nx_cooking/domain/week_section.dart';

export 'package:nx_cooking/data/cooking_task/cooking_task_schema_provider.dart';
export 'package:nx_cooking/data/recipe/recipe_schema_provider.dart';

/// Recipe [ModelType] mapped for tag UI (filter sheet, tag admin).
final recipeSchemaViewProvider = FutureProvider<ModelTypeView>((ref) async {
  final m = await ref.watch(recipeSchemaProvider.future);
  return modelTypeViewFromKgql(m);
});

/// All [Item] models with the CookingItem trait (ingredient catalog).
final cookingItemsProvider = FutureProvider<List<CookingItemEntry>>((
  ref,
) async {
  await ref.watch(authenticatedUserProvider.future);
  final client = ref.watch(graphqlClientProvider);
  final models = await fetchKgqlModels(
    client,
    filter: <String, dynamic>{
      'model_type': 'Item',
      'relation_filters': <Map<String, dynamic>>[
        <String, dynamic>{'model_type': 'CookingItem'},
      ],
    },
    struct: <String, dynamic>{'id': true, 'name': true},
  );
  final list =
      models.map((m) => CookingItemEntry(id: m.id, name: m.name)).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return list;
});

class RecipeListFilterNotifier extends Notifier<RecipeFilter?> {
  @override
  RecipeFilter? build() => null;

  void setFilter(RecipeFilter? value) => state = value;
}

/// Active tag filters for recipe list (server-side KGQL `tag_filters`).
final recipeListFilterProvider =
    NotifierProvider<RecipeListFilterNotifier, RecipeFilter?>(
      RecipeListFilterNotifier.new,
    );

class RecipeSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String value) => state = value;

  void clear() => state = '';
}

/// Raw text in the Recipes sub-bar search field.
final recipeSearchQueryProvider =
    NotifierProvider<RecipeSearchQueryNotifier, String>(
      RecipeSearchQueryNotifier.new,
    );

/// Debounced results for [recipeSearchQueryProvider]. `null` when the query
/// is empty (hide overlay). Otherwise a (possibly empty) list from the server.
final recipeSearchResultsProvider =
    FutureProvider.autoDispose<List<RecipeSearchResult>?>((ref) async {
      var q = ref.watch(recipeSearchQueryProvider);
      for (;;) {
        final t = q.trim();
        if (t.isEmpty) return null;
        await Future<void>.delayed(const Duration(milliseconds: 300));
        if (ref.read(recipeSearchQueryProvider).trim() != t) {
          q = ref.read(recipeSearchQueryProvider);
          continue;
        }
        await ref.watch(authenticatedUserProvider.future);
        return ref.read(recipeRepositoryProvider).searchRecipes(t);
      }
    });

/// Stats tab only (in-memory).
final cookingRepositoryProvider = Provider<CookingRepository>(
  (ref) => FakeCookingRepository(),
);

/// Monday 00:00 local for the week shown on Week / Buy.
final selectedWeekStartProvider =
    NotifierProvider<SelectedWeekStartNotifier, DateTime>(
      SelectedWeekStartNotifier.new,
    );

class SelectedWeekStartNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => weekStartMonday(DateTime.now());

  void setToContaining(DateTime anyDay) {
    state = weekStartMonday(anyDay);
  }

  void shiftWeeks(int delta) {
    state = state.add(Duration(days: 7 * delta));
  }
}

/// Recipe CRUD via PGDB KGQL.
final recipeRepositoryProvider = Provider<RecipeRepository>((ref) {
  return KgqlRecipeRepository(
    client: ref.watch(graphqlClientProvider),
    loadRecipeSchema: () => ref.read(recipeSchemaProvider.future),
  );
});

final cookingPlanRepositoryProvider = Provider<CookingPlanRepository>((ref) {
  return KgqlCookingPlanRepository(
    client: ref.watch(graphqlClientProvider),
    loadCookingTaskSchema: () => ref.read(cookingTaskSchemaProvider.future),
  );
});

/// Cached list for recipe tab + sub-bar count.
///
/// [IndexedStack] keeps [RecipesPage] built, so this future runs on cold start
/// (not only when the Recipes tab is visible). Gate on auth first so
/// [graphqlClientProvider] is built from saved/login credentials rather than
/// its unauthenticated fallback endpoint.
final recipeListProvider = FutureProvider<List<RecipeSummary>>((ref) async {
  debugPrint('[nx_cooking:recipeListProvider] start');
  try {
    final user = await ref.watch(authenticatedUserProvider.future);
    debugPrint(
      '[nx_cooking:recipeListProvider] authenticated user=${user.userId} '
      'preset=${user.preset.key}',
    );
    final filter = ref.watch(recipeListFilterProvider);
    final list = await ref
        .watch(recipeRepositoryProvider)
        .fetchRecipes(filter: filter);
    debugPrint('[nx_cooking:recipeListProvider] success count=${list.length}');
    return list;
  } catch (e, st) {
    debugPrint('[nx_cooking:recipeListProvider] caught: $e\n$st');
    rethrow;
  }
});

/// One recipe (detail screen).
final recipeDetailProvider = FutureProvider.family<RecipeDetail?, int>((
  ref,
  id,
) async {
  final user = await ref.watch(authenticatedUserProvider.future);
  debugPrint(
    '[nx_cooking:recipeDetailProvider] authenticated user=${user.userId} '
    'preset=${user.preset.key} recipe=$id',
  );
  return ref.watch(recipeRepositoryProvider).fetchRecipeDetail(id);
});

/// One planned [CookingTask] for [CookingTaskViewPage] (by task id).
final cookingTaskDetailProvider =
    FutureProvider.family<CookingTaskDetail?, int>((ref, taskId) async {
      await ref.watch(authenticatedUserProvider.future);
      return ref.watch(cookingPlanRepositoryProvider).fetchTaskDetail(taskId);
    });

/// Week tab: seven day rows from `CookingTask` in PGDB.
final weekSectionsProvider = FutureProvider<List<WeekDaySection>>((ref) async {
  await ref.watch(authenticatedUserProvider.future);
  final start = ref.watch(selectedWeekStartProvider);
  return ref.watch(cookingPlanRepositoryProvider).fetchWeek(start);
});

/// Buy tab: ingredients grouped by planned meal for the selected week.
final shoppingSnapshotProvider = FutureProvider<ShoppingListSnapshot>((
  ref,
) async {
  await ref.watch(authenticatedUserProvider.future);
  final start = ref.watch(selectedWeekStartProvider);
  return ref.watch(cookingPlanRepositoryProvider).fetchShopping(start);
});
