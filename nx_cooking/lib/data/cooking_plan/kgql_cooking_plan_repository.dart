import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:intl/intl.dart';
import 'package:nx_db/kgql.dart';
import 'package:nx_cooking/core/dates/week_calendar.dart';
import 'package:nx_cooking/data/cooking_plan/cooking_plan_attr_keys.dart';
import 'package:nx_cooking/data/cooking_plan/cooking_plan_mapper.dart';
import 'package:nx_cooking/data/recipe/recipe_attr_keys.dart';
import 'package:nx_cooking/domain/cooking_plan_repository.dart';
import 'package:nx_cooking/domain/cooking_plan_detail.dart';
import 'package:nx_cooking/domain/shopping.dart';
import 'package:nx_cooking/domain/week_section.dart';

class KgqlCookingPlanRepository implements CookingPlanRepository {
  KgqlCookingPlanRepository({
    required GraphQLClient client,
    required Future<ModelType> Function() loadCookingSchema,
  }) : _client = client,
       _loadCookingSchema = loadCookingSchema;

  final GraphQLClient _client;
  final Future<ModelType> Function() _loadCookingSchema;

  Map<String, dynamic> _cookingStruct(ModelType schema) {
    final base = buildKgqlStructFromSchema(schema);
    final merged = Map<String, dynamic>.from(base);
    merged['relations'] = {
      'relation_id': true,
      'model_id': true,
      'model_type': true,
      'name': true,
      'description': true,
      'relation_attributes': {'key': true, 'value': true, 'value_type': true},
    };
    merged[kRecipeModelTypeName] = {
      'id': true,
      'name': true,
      'description': true,
      kRecipeAttrPrepTime: true,
      kRecipeAttrServings: true,
      kRecipeAttrInstructions: true,
      kItemModelTypeName: {'id': true, 'name': true, 'description': true},
      'tags': true,
      'relations': {
        'relation_id': true,
        'model_id': true,
        'model_type': true,
        'relation_attributes': {'key': true, 'value': true, 'value_type': true},
      },
    };
    return merged;
  }

  String _isoDateTime(DateTime d) {
    final x = dateOnly(d);
    return DateTime(x.year, x.month, x.day).toIso8601String();
  }

  Future<List<Model>> _plansForWeek(DateTime weekStartMondayLocal) async {
    final schema = await _loadCookingSchema();
    final struct = _cookingStruct(schema);
    final start = dateOnly(weekStartMondayLocal);
    final endExclusive = start.add(const Duration(days: 7));
    return fetchKgqlModels(
      _client,
      filter: {
        'model_type': kCookingModelTypeName,
        'filters': [
          {
            'key': kCookingAttrScheduledStartTime,
            'op': '>=',
            'value': _isoDateTime(start),
          },
          {
            'key': kCookingAttrScheduledStartTime,
            'op': '<',
            'value': _isoDateTime(endExclusive),
          },
        ],
      },
      struct: struct,
    );
  }

  @override
  Future<List<WeekDaySection>> fetchWeek(DateTime weekStartMonday) async {
    final plans = await _plansForWeek(weekStartMonday);
    return buildWeekSections(
      weekStartMondayLocal: weekStartMonday,
      plans: plans,
    );
  }

  @override
  Future<ShoppingListSnapshot> fetchShopping(DateTime weekStartMonday) async {
    final plans = await _plansForWeek(weekStartMonday);
    return buildShoppingSnapshot(
      weekStartMondayLocal: weekStartMonday,
      plans: plans,
    );
  }

  @override
  Future<CookingPlanDetail?> fetchPlanDetail(int planId) async {
    final schema = await _loadCookingSchema();
    final struct = _cookingStruct(schema);
    final plan = await fetchKgqlModelById(
      _client,
      modelTypeName: kCookingModelTypeName,
      id: planId,
      struct: struct,
    );
    if (plan == null) {
      return null;
    }
    return cookingPlanDetailFromModel(plan);
  }

  @override
  Future<int> planRecipe({
    required int recipeId,
    required DateTime date,
  }) async {
    final day = dateOnly(date);
    final recipe = await fetchKgqlModelById(
      _client,
      modelTypeName: kRecipeModelTypeName,
      id: recipeId,
      struct: const {'id': true, 'name': true},
    );
    final recipeName = recipe?.name ?? 'Recipe';
    final label = DateFormat('MMM d').format(day);
    final req = SetModelRequest(
      modelType: kCookingModelTypeName,
      name: '$recipeName · $label',
      attributes: [
        SetModelAttribute(
          key: kCookingAttrScheduledStartTime,
          value: DateTime(day.year, day.month, day.day).toIso8601String(),
        ),
        SetModelAttribute(
          key: kCookingAttrPlanningStatus,
          value: kCookingPlanningStatusPlanned,
        ),
      ],
      relations: [
        ModelRelation(
          modelType: kRecipeModelTypeName,
          link: [recipeId],
          attributes: [
            RelationAttribute(
              key: kCooksRecipeRelationAttrIngredientChecks,
              value: <String, dynamic>{},
            ),
          ],
        ),
      ],
    );
    return setKgqlModel(_client, req);
  }

  @override
  Future<void> updateIngredientChecks(
    int planId,
    int cooksRecipeRelationId,
    Map<String, bool> checks,
  ) async {
    if (cooksRecipeRelationId == 0) {
      throw StateError('Missing cooks_recipe relation id');
    }
    final value = <String, dynamic>{
      for (final e in checks.entries) e.key: e.value,
    };
    await setKgqlModel(
      _client,
      SetModelRequest(
        id: planId,
        relations: [
          ModelRelation(
            id: cooksRecipeRelationId,
            attributes: [
              RelationAttribute(
                key: kCooksRecipeRelationAttrIngredientChecks,
                value: value,
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Future<void> deletePlan(int planId) async {
    await setKgqlModel(_client, SetModelRequest(id: planId, delete: true));
  }

  @override
  Future<void> updatePlanDate(int planId, DateTime newDate) async {
    final day = dateOnly(newDate);
    await setKgqlModel(
      _client,
      SetModelRequest(
        id: planId,
        attributes: [
          SetModelAttribute(
            key: kCookingAttrScheduledStartTime,
            value: DateTime(day.year, day.month, day.day).toIso8601String(),
          ),
        ],
      ),
    );
  }

  @override
  Future<void> updatePlanNotes(int planId, String? notes) async {
    final t = notes?.trim();
    await setKgqlModel(
      _client,
      SetModelRequest(id: planId, description: t == null || t.isEmpty ? '' : t),
    );
  }
}
