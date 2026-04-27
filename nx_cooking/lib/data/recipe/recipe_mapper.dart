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

int? _intAttr(Model m, String key) {
  final d = m.attrDouble(key);
  if (d == null) {
    return null;
  }
  return d.round();
}

String _metaLine(Model m) {
  final n = m.relations?[kItemModelTypeName]?.length ?? 0;
  final prep = _intAttr(m, kRecipeAttrPrepTime);
  final prepStr = prep != null ? '$prep min prep' : '—';
  return '$n ingredients · $prepStr';
}

RecipeSummary recipeSummaryFromModel(Model m) {
  return RecipeSummary(
    id: m.id.toString(),
    title: m.name,
    metaLine: _metaLine(m),
    tags: _tagListFromModel(m),
    ingredientCount: m.relations?[kItemModelTypeName]?.length ?? 0,
    prepTimeMinutes: _intAttr(m, kRecipeAttrPrepTime),
  );
}

List<String> _instructionLinesFromModel(Model m) {
  return instructionLinesFromRaw(m.attrString(kRecipeAttrInstructions));
}

RecipeDetail recipeDetailFromModel(Model m) {
  final items = m.relations?[kItemModelTypeName] ?? const <Model>[];
  final relList = m.relationsList ?? const <Relation>[];

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
    prepTimeMinutes: _intAttr(m, kRecipeAttrPrepTime),
    servings: _intAttr(m, kRecipeAttrServings),
    notes: _recipeUserNotes(m.description),
    crawlerPayload: crawlerPayloadFromModelAttributes(m.attributes),
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
