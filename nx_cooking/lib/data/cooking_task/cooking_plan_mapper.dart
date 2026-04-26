import 'package:intl/intl.dart';
import 'package:nx_db/kgql.dart';
import 'package:nx_cooking/core/dates/week_calendar.dart';
import 'package:nx_cooking/data/cooking_task/cooking_task_attr_keys.dart';
import 'package:nx_cooking/data/recipe/recipe_attr_keys.dart';
import 'package:nx_cooking/domain/meal_status.dart';
import 'package:nx_cooking/domain/shopping.dart';
import 'package:nx_cooking/domain/week_section.dart';

String _ingredientAmountFromDescription(String? description) {
  if (description == null) {
    return '';
  }
  final t = description.trim();
  if (t.isEmpty) {
    return '';
  }
  final idx = t.indexOf(' · ');
  if (idx == -1) {
    return t;
  }
  return t.substring(0, idx).trim();
}

/// Per-item buy state when backend exposes `ingredient_checks` on relations.
Map<String, bool>? _ingredientChecksFromTask(Model task) {
  // KGQL read path does not yet surface relation attributes on `relationsList`.
  return null;
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
    final checks = _ingredientChecksFromTask(t);
    final header = '${DateFormat('EEE d').format(day)} · ${recipe.name}';
    final shopItems = <ShoppingItem>[];
    for (final it in items) {
      final idStr = '${it.id}';
      final initial = checks != null && checks[idStr] == true;
      shopItems.add(
        ShoppingItem(
          name: it.name,
          amount: _ingredientAmountFromDescription(it.description),
          initialChecked: initial,
        ),
      );
    }
    groups.add(ShoppingMealGroup(header: header, items: shopItems));
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
