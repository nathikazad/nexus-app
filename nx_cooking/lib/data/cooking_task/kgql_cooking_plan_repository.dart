import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:intl/intl.dart';
import 'package:nx_db/kgql.dart';
import 'package:nx_cooking/core/dates/week_calendar.dart';
import 'package:nx_cooking/data/cooking_task/cooking_plan_mapper.dart';
import 'package:nx_cooking/data/cooking_task/cooking_task_attr_keys.dart';
import 'package:nx_cooking/data/recipe/recipe_attr_keys.dart';
import 'package:nx_cooking/domain/cooking_plan_repository.dart';
import 'package:nx_cooking/domain/cooking_task_detail.dart';
import 'package:nx_cooking/domain/shopping.dart';
import 'package:nx_cooking/domain/week_section.dart';

class KgqlCookingPlanRepository implements CookingPlanRepository {
  KgqlCookingPlanRepository({
    required GraphQLClient client,
    required Future<ModelType> Function() loadCookingTaskSchema,
  }) : _client = client,
       _loadCookingTaskSchema = loadCookingTaskSchema;

  final GraphQLClient _client;
  final Future<ModelType> Function() _loadCookingTaskSchema;

  Map<String, dynamic> _cookingTaskStruct(ModelType schema) {
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

  String _isoDate(DateTime d) {
    final x = dateOnly(d);
    final m = x.month.toString().padLeft(2, '0');
    final day = x.day.toString().padLeft(2, '0');
    return '${x.year}-$m-$day';
  }

  Future<List<Model>> _tasksForWeek(DateTime weekStartMondayLocal) async {
    final schema = await _loadCookingTaskSchema();
    final struct = _cookingTaskStruct(schema);
    final start = dateOnly(weekStartMondayLocal);
    final endExclusive = start.add(const Duration(days: 7));
    return fetchKgqlModels(
      _client,
      filter: {
        'model_type': kCookingTaskModelTypeName,
        'filters': [
          {'key': kTaskAttrDate, 'op': '>=', 'value': _isoDate(start)},
          {'key': kTaskAttrDate, 'op': '<', 'value': _isoDate(endExclusive)},
        ],
      },
      struct: struct,
    );
  }

  @override
  Future<List<WeekDaySection>> fetchWeek(DateTime weekStartMonday) async {
    final tasks = await _tasksForWeek(weekStartMonday);
    return buildWeekSections(
      weekStartMondayLocal: weekStartMonday,
      tasks: tasks,
    );
  }

  @override
  Future<ShoppingListSnapshot> fetchShopping(DateTime weekStartMonday) async {
    final tasks = await _tasksForWeek(weekStartMonday);
    return buildShoppingSnapshot(
      weekStartMondayLocal: weekStartMonday,
      tasks: tasks,
    );
  }

  @override
  Future<CookingTaskDetail?> fetchTaskDetail(int taskId) async {
    final schema = await _loadCookingTaskSchema();
    final struct = _cookingTaskStruct(schema);
    final task = await fetchKgqlModelById(
      _client,
      modelTypeName: kCookingTaskModelTypeName,
      id: taskId,
      struct: struct,
    );
    if (task == null) {
      return null;
    }
    return cookingTaskDetailFromModel(task);
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
      modelType: kCookingTaskModelTypeName,
      name: '$recipeName · $label',
      attributes: [
        SetModelAttribute(
          key: kTaskAttrDate,
          value: DateTime(day.year, day.month, day.day).toIso8601String(),
        ),
        SetModelAttribute(key: kCookingTaskAttrStatus, value: 'planned'),
      ],
      relations: [
        ModelRelation(
          modelType: kRecipeModelTypeName,
          link: [recipeId],
          attributes: [
            RelationAttribute(
              key: kForRecipeRelationAttrIngredientChecks,
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
    int taskId,
    int forRecipeRelationId,
    Map<String, bool> checks,
  ) async {
    if (forRecipeRelationId == 0) {
      throw StateError('Missing for_recipe relation id');
    }
    final value = <String, dynamic>{
      for (final e in checks.entries) e.key: e.value,
    };
    await setKgqlModel(
      _client,
      SetModelRequest(
        id: taskId,
        relations: [
          ModelRelation(
            id: forRecipeRelationId,
            attributes: [
              RelationAttribute(
                key: kForRecipeRelationAttrIngredientChecks,
                value: value,
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Future<void> deleteTask(int taskId) async {
    await setKgqlModel(_client, SetModelRequest(id: taskId, delete: true));
  }

  @override
  Future<void> updateTaskDate(int taskId, DateTime newDate) async {
    final day = dateOnly(newDate);
    await setKgqlModel(
      _client,
      SetModelRequest(
        id: taskId,
        attributes: [
          SetModelAttribute(
            key: kTaskAttrDate,
            value: DateTime(day.year, day.month, day.day).toIso8601String(),
          ),
        ],
      ),
    );
  }

  @override
  Future<void> updateTaskNotes(int taskId, String? notes) async {
    final t = notes?.trim();
    if (t == null || t.isEmpty) {
      await setKgqlModel(
        _client,
        SetModelRequest(
          id: taskId,
          attributes: [
            SetModelAttribute(key: kCookingTaskAttrNotes, delete: true),
          ],
        ),
      );
      return;
    }
    await setKgqlModel(
      _client,
      SetModelRequest(
        id: taskId,
        attributes: [SetModelAttribute(key: kCookingTaskAttrNotes, value: t)],
      ),
    );
  }
}
