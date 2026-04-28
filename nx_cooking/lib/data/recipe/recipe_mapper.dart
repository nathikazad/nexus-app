import 'package:nx_db/kgql.dart';
import 'package:nx_cooking/data/recipe/ingredient_from_relation.dart';
import 'package:nx_cooking/data/recipe/instruction_lines.dart';
import 'package:nx_cooking/data/recipe/recipe_attr_keys.dart';
import 'package:nx_cooking/domain/recipe.dart';
import 'package:nx_cooking/domain/recipe_detail.dart';

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

/// Per-system tag assignments for edit UI and [RecipeDetail.tagsMap].
Map<String, List<String>> recipeTagMapFromModel(Model m) {
  final tags = m.tags;
  if (tags == null || tags.isEmpty) {
    return const {};
  }
  return {
    for (final e in tags.entries) e.key: List<String>.from(e.value),
  };
}

int? _intAttr(Model m, String key) {
  final d = m.attrDouble(key);
  if (d == null) {
    return null;
  }
  return d.round();
}

String _metaLine(Model m) {
  final n = m.relations?[kItemModelTypeName]?.length ?? 0;
  final payload = crawlerPayloadFromModelAttributes(m.attributes);
  final total = crawlerPayloadNonEmptyString(payload, 'total_time');
  if (total != null) {
    return '$n ingredients · $total total';
  }
  final prep = _intAttr(m, kRecipeAttrPrepTime);
  final prepFromPayload = crawlerPayloadNonEmptyString(payload, 'prep_time');
  final prepStr =
      prepFromPayload ?? (prep != null ? '$prep min prep' : '—');
  return '$n ingredients · $prepStr';
}

RecipeSummary recipeSummaryFromModel(Model m) {
  return RecipeSummary(
    id: m.id.toString(),
    title: m.name,
    metaLine: _metaLine(m),
    ingredientCount: m.relations?[kItemModelTypeName]?.length ?? 0,
    prepTimeMinutes: _intAttr(m, kRecipeAttrPrepTime),
  );
}

List<String> _instructionLinesFromModel(Model m) {
  return instructionLinesFromRaw(m.attrString(kRecipeAttrInstructions));
}

const _nutritionHighlightLabels = [
  'Calories',
  'Carbohydrates',
  'Protein',
  'Fat',
];

List<NutritionServingFact> _nutritionHighlightsFromPayload(
  Map<String, dynamic>? payload,
) {
  if (payload == null) {
    return const [];
  }
  final raw = payload['nutrition_per_serving'];
  if (raw is! List) {
    return const [];
  }
  final byLowerNutrient = <String, String>{};
  for (final item in raw) {
    if (item is! Map) {
      continue;
    }
    final map = Map<String, dynamic>.from(item);
    final nutrientRaw = map['nutrient'];
    final amountRaw = map['amount'];
    if (nutrientRaw == null || amountRaw == null) {
      continue;
    }
    final nutrient = nutrientRaw.toString().trim();
    final amount = amountRaw.toString().trim();
    if (nutrient.isEmpty || amount.isEmpty) {
      continue;
    }
    byLowerNutrient[nutrient.toLowerCase()] = amount;
  }
  final out = <NutritionServingFact>[];
  for (final label in _nutritionHighlightLabels) {
    final amount = byLowerNutrient[label.toLowerCase()];
    if (amount != null) {
      out.add(NutritionServingFact(label: label, amount: amount));
    }
  }
  return out;
}

RecipeDetail recipeDetailFromModel(Model m) {
  final items = m.relations?[kItemModelTypeName] ?? const <Model>[];
  final relList = m.relationsList ?? const <Relation>[];
  final prepMin = _intAttr(m, kRecipeAttrPrepTime);
  final payload = crawlerPayloadFromModelAttributes(m.attributes);
  final prepDisplay = crawlerPayloadNonEmptyString(payload, 'prep_time') ??
      (prepMin != null ? '$prepMin min' : null);

  final lines = <IngredientLine>[];
  for (final item in items) {
    final rel = relationForItemModel(relList, item.id);
    lines.add(
      IngredientLine(
        name: item.name,
        amount: ingredientAmountDisplay(rel, item.description),
        relationId: rel?.relationId,
        itemId: item.id,
        groupName: ingredientGroupName(rel),
        preparation: ingredientPreparation(rel),
      ),
    );
  }

  return RecipeDetail(
    id: m.id,
    title: m.name,
    tags: _tagListFromModel(m),
    tagsMap: recipeTagMapFromModel(m),
    prepTimeMinutes: prepMin,
    servings: _intAttr(m, kRecipeAttrServings),
    notes: _recipeUserNotes(m.description),
    crawlerPayload: payload,
    prepTimeDisplay: prepDisplay,
    cookTimeDisplay: crawlerPayloadNonEmptyString(payload, 'cook_time'),
    totalTimeDisplay: crawlerPayloadNonEmptyString(payload, 'total_time'),
    nutritionPerServingHighlights: _nutritionHighlightsFromPayload(payload),
    ingredients: lines,
    instructionLines: _instructionLinesFromModel(m),
  );
}

/// Item.description may be `"{amount} · {seed label}"` from demo seed; prefer left side.
String? _recipeUserNotes(String? description) {
  if (description == null) {
    return null;
  }
  final t = description.trim();
  if (t.isEmpty) {
    return null;
  }
  if (t.contains('nx_cooking demo seed')) {
    return null;
  }
  return t;
}

List<SetModelAttribute> _recipeAttributes(RecipeFormData form) {
  final prep = int.tryParse(form.prepTimeMinutesText.trim());
  final serv = int.tryParse(form.servingsText.trim());
  final steps = form.instructionSteps
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .join('\n');
  return [
    if (prep != null)
      SetModelAttribute(key: kRecipeAttrPrepTime, value: prep.toDouble()),
    if (serv != null)
      SetModelAttribute(key: kRecipeAttrServings, value: serv.toDouble()),
    SetModelAttribute(key: kRecipeAttrInstructions, value: steps),
  ];
}

List<RelationAttribute> _hasIngredientRelationAttributes(
  RecipeIngredientFormLine line,
  String displayAmount,
) {
  return [
    RelationAttribute(
      key: kHasIngredientRelationAttrQuantity,
      value: displayAmount.isEmpty ? ' ' : displayAmount,
    ),
    RelationAttribute(
      key: kHasIngredientRelationAttrGroupName,
      value: line.groupName.trim(),
    ),
    RelationAttribute(
      key: kHasIngredientRelationAttrNotes,
      value: line.preparation.trim(),
    ),
  ];
}

List<ModelRelation> _ingredientRelationsForCreate(RecipeFormData form) {
  final out = <ModelRelation>[];
  for (final line in form.ingredients) {
    if (line.name.trim().isEmpty) {
      continue;
    }
    final displayAmount = [
      line.quantityText.trim(),
      line.unit.trim(),
    ].where((e) => e.isNotEmpty).join(' ');
    out.add(
      ModelRelation(
        modelType: kItemModelTypeName,
        create: [
          {'name': line.name.trim(), 'description': displayAmount},
        ],
        attributes: _hasIngredientRelationAttributes(line, displayAmount),
      ),
    );
  }
  return out;
}

SetModelRequest setRequestForCreateRecipe(RecipeFormData form) {
  return SetModelRequest(
    modelType: kRecipeModelTypeName,
    name: form.name.trim(),
    description: form.notes.trim().isEmpty ? null : form.notes.trim(),
    attributes: _recipeAttributes(form),
    relations: _ingredientRelationsForCreate(form),
  );
}

List<ModelRelation> _ingredientRelationDeletes(RecipeDetail existing) {
  return [
    for (final ing in existing.ingredients)
      if (ing.relationId != null)
        ModelRelation(id: ing.relationId, delete: true),
  ];
}

List<ModelRelation> _ingredientRelationsForUpdate(RecipeFormData form) {
  return _ingredientRelationsForCreate(form);
}

SetModelRequest setRequestForUpdateRecipeWithIngredients(
  int id,
  RecipeFormData form,
  RecipeDetail previous,
) {
  return SetModelRequest(
    id: id,
    name: form.name.trim(),
    description: form.notes.trim().isEmpty ? null : form.notes.trim(),
    attributes: _recipeAttributes(form),
    relations: [
      ..._ingredientRelationDeletes(previous),
      ..._ingredientRelationsForUpdate(form),
    ],
  );
}

SetModelRequest setRequestForDeleteRecipe(int id) {
  return SetModelRequest(id: id, delete: true);
}

SetModelRequest setRequestForUpdateRecipeMeta(
  int id,
  String name,
  Map<String, List<String>> tags,
) {
  return SetModelRequest(
    id: id,
    name: name.trim(),
    tags: [
      for (final e in tags.entries)
        if (e.value.isNotEmpty)
          SetModelTag(system: e.key, nodes: e.value)
        else
          SetModelTag(system: e.key, nodes: const [], clear: true),
    ],
  );
}
