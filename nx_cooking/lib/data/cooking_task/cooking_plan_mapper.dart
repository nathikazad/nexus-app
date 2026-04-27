import 'dart:convert';

import 'package:intl/intl.dart';
import 'package:nx_db/kgql.dart';
import 'package:nx_cooking/core/dates/week_calendar.dart';
import 'package:nx_cooking/data/cooking_task/cooking_task_attr_keys.dart';
import 'package:nx_cooking/data/recipe/ingredient_from_relation.dart';
import 'package:nx_cooking/data/recipe/instruction_lines.dart';
import 'package:nx_cooking/data/recipe/recipe_attr_keys.dart';
import 'package:nx_cooking/domain/cooking_task_detail.dart';
import 'package:nx_cooking/domain/meal_status.dart';
import 'package:nx_cooking/domain/shopping.dart';
import 'package:nx_cooking/domain/week_section.dart';

/// `for_recipe` edge to the recipe (for relation id + `ingredient_checks` JSON).
Relation? _forRecipeRelationFromTask(Model task) {
  final list = task.relationsList;
  if (list == null) {
    return null;
  }
  for (final r in list) {
    if (r.modelType == kRecipeModelTypeName) {
      return r;
    }
  }
  return null;
}

Map<String, bool>? _ingredientChecksFromTask(Model task) {
  final rel = _forRecipeRelationFromTask(task);
  final raw = rel?.relationAttributes?[kForRecipeRelationAttrIngredientChecks];
  if (raw == null) {
    return null;
  }
  final checks = _checksMapFromRaw(raw);
  if (checks == null) {
    return null;
  }
  final out = <String, bool>{};
  for (final e in checks.entries) {
    final k = e.key.toString();
    final v = e.value;
    if (v is bool) {
      out[k] = v;
    } else if (v is num) {
      out[k] = v != 0;
    } else {
      final s = v.toString().toLowerCase();
      if (s == 'true') {
        out[k] = true;
      } else if (s == 'false') {
        out[k] = false;
      }
    }
  }
  return out.isEmpty ? <String, bool>{} : out;
}

Map<dynamic, dynamic>? _checksMapFromRaw(dynamic raw) {
  if (raw is Map) {
    return raw;
  }
  if (raw is String) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return const {};
    }
    final decoded = jsonDecode(trimmed);
    if (decoded is Map) {
      return decoded;
    }
  }
  return null;
}

int? _intAttr(Model m, String key) {
  final d = m.attrDouble(key);
  if (d == null) {
    return null;
  }
  return d.round();
}

List<String> _tagListFromModel(Model m) {
  final tags = m.tags;
  if (tags == null || tags.isEmpty) {
    return const [];
  }
  final out = <String>[];
  for (final e in tags.entries) {
    out.addAll(e.value);
  }
  return out;
}

(int checked, int total) _checkCounts(
  List<Model> items,
  Map<String, bool>? checks,
) {
  if (items.isEmpty) {
    return (0, 0);
  }
  var c = 0;
  for (final it in items) {
    final idStr = '${it.id}';
    if (checks != null && checks[idStr] == true) {
      c++;
    }
  }
  return (c, items.length);
}

WeekMealCard? weekMealCardFromTask(Model task) {
  final recipe = task.relations?[kRecipeModelTypeName]?.firstOrNull;
  if (recipe == null) {
    return null;
  }
  final status = task.attrString(kCookingTaskAttrStatus)?.toLowerCase() ?? '';
  if (status == 'skipped') {
    return null;
  }

  final items = recipe.relations?[kItemModelTypeName] ?? const <Model>[];
  final checks = _ingredientChecksFromTask(task);
  final (got, need) = _checkCounts(items, checks);

  final kind = switch (status) {
    'cooking' => MealCardKind.cookingInProgress,
    'done' => MealCardKind.done,
    _ => MealCardKind.planned,
  };

  final badge = need == 0 ? '' : '$got/$need items';
  final subtitle = switch (status) {
    'cooking' => 'Cooking in progress',
    'done' => 'Cooked',
    _ =>
      need == 0
          ? 'Planned'
          : (got >= need ? 'Ready to cook' : 'Needs shopping'),
  };

  return WeekMealCard(
    taskId: task.id,
    recipeId: recipe.id,
    title: recipe.name,
    kind: kind,
    badge: badge,
    subtitle: subtitle,
    showPing: status == 'cooking',
  );
}

List<WeekDaySection> buildWeekSections({
  required DateTime weekStartMondayLocal,
  required List<Model> tasks,
}) {
  final weekStart = dateOnly(weekStartMondayLocal);
  final byDay = <DateTime, Model>{};
  for (final t in tasks) {
    final status = t.attrString(kCookingTaskAttrStatus)?.toLowerCase() ?? '';
    if (status == 'skipped') {
      continue;
    }
    final d = t.attrDateTime(kTaskAttrDate);
    if (d == null) {
      continue;
    }
    final day = dateOnly(d);
    if (day.isBefore(weekStart) ||
        day.isAfter(weekStart.add(const Duration(days: 6)))) {
      continue;
    }
    byDay.putIfAbsent(day, () => t);
  }

  final today = dateOnly(DateTime.now());
  final dayTitle = DateFormat('EEEE, MMM d');

  return List.generate(7, (i) {
    final day = weekStart.add(Duration(days: i));
    final task = byDay[day];
    final meal = task == null ? null : weekMealCardFromTask(task);
    return WeekDaySection(
      date: day,
      dayLabel: dayTitle.format(day),
      isToday: isSameDate(day, today),
      meal: meal,
    );
  });
}

ShoppingListSnapshot buildShoppingSnapshot({
  required DateTime weekStartMondayLocal,
  required List<Model> tasks,
}) {
  final weekStart = dateOnly(weekStartMondayLocal);
  final groups = <ShoppingMealGroup>[];

  final sorted = [...tasks]
    ..sort((a, b) {
      final da = a.attrDateTime(kTaskAttrDate);
      final db = b.attrDateTime(kTaskAttrDate);
      if (da == null && db == null) {
        return a.id.compareTo(b.id);
      }
      if (da == null) {
        return 1;
      }
      if (db == null) {
        return -1;
      }
      final c = da.compareTo(db);
      if (c != 0) {
        return c;
      }
      return a.id.compareTo(b.id);
    });

  for (final t in sorted) {
    final status = t.attrString(kCookingTaskAttrStatus)?.toLowerCase() ?? '';
    if (status == 'skipped') {
      continue;
    }
    final d = t.attrDateTime(kTaskAttrDate);
    if (d == null) {
      continue;
    }
    final day = dateOnly(d);
    if (day.isBefore(weekStart) ||
        day.isAfter(weekStart.add(const Duration(days: 6)))) {
      continue;
    }
    final recipe = t.relations?[kRecipeModelTypeName]?.firstOrNull;
    if (recipe == null) {
      continue;
    }
    final items = recipe.relations?[kItemModelTypeName] ?? const <Model>[];
    if (items.isEmpty) {
      continue;
    }
    final recipeRelList = recipe.relationsList ?? const <Relation>[];
    final checks = _ingredientChecksFromTask(t);
    final forRecipe = _forRecipeRelationFromTask(t);
    final taskRelId = forRecipe?.relationId ?? 0;
    final header = '${DateFormat('EEE d').format(day)} · ${recipe.name}';
    final shopItems = <ShoppingItem>[];
    for (final it in items) {
      final idStr = '${it.id}';
      final initial = checks != null && checks[idStr] == true;
      final edge = relationForItemModel(recipeRelList, it.id);
      shopItems.add(
        ShoppingItem(
          taskId: t.id,
          taskRelationId: taskRelId,
          itemId: it.id,
          name: it.name,
          amount: ingredientAmountDisplay(edge, it.description),
          initialChecked: initial,
          groupName: ingredientGroupName(edge),
          preparation: ingredientPreparation(edge),
        ),
      );
    }
    groups.add(
      ShoppingMealGroup(
        header: header,
        taskId: t.id,
        taskRelationId: taskRelId,
        items: shopItems,
      ),
    );
  }

  var purchased = 0;
  var total = 0;
  for (final g in groups) {
    for (final i in g.items) {
      total++;
      if (i.initialChecked) {
        purchased++;
      }
    }
  }

  return ShoppingListSnapshot(
    purchasedCount: purchased,
    totalCount: total,
    groups: groups,
  );
}

/// Full task + recipe for [CookingTaskViewPage]. Returns null if task has no recipe link.
CookingTaskDetail? cookingTaskDetailFromModel(Model task) {
  final recipe = task.relations?[kRecipeModelTypeName]?.firstOrNull;
  final forRecipe = _forRecipeRelationFromTask(task);
  if (recipe == null || forRecipe == null) {
    return null;
  }
  final planned = task.attrDateTime(kTaskAttrDate);
  if (planned == null) {
    return null;
  }
  final status = task.attrString(kCookingTaskAttrStatus) ?? 'planned';
  final checks = _ingredientChecksFromTask(task) ?? <String, bool>{};
  final itemModels = recipe.relations?[kItemModelTypeName] ?? const <Model>[];
  final relList = recipe.relationsList ?? const <Relation>[];
  final ingredients = <TaskIngredient>[];
  for (final it in itemModels) {
    final idStr = '${it.id}';
    final edge = relationForItemModel(relList, it.id);
    ingredients.add(
      TaskIngredient(
        itemId: it.id,
        name: it.name,
        amount: ingredientAmountDisplay(edge, it.description),
        checked: checks[idStr] == true,
        groupName: ingredientGroupName(edge),
        preparation: ingredientPreparation(edge),
      ),
    );
  }
  return CookingTaskDetail(
    taskId: task.id,
    taskRelationId: forRecipe.relationId,
    recipeId: recipe.id,
    recipeName: recipe.name,
    plannedDate: planned,
    status: status,
    tags: _tagListFromModel(recipe),
    prepTimeMinutes: _intAttr(recipe, kRecipeAttrPrepTime),
    servings: _intAttr(recipe, kRecipeAttrServings),
    notes: task.attrString(kCookingTaskAttrNotes),
    ingredients: ingredients,
    instructionLines: instructionLinesFromRaw(
      recipe.attrString(kRecipeAttrInstructions),
    ),
  );
}
