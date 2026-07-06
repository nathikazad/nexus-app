import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/kgql.dart';
import 'package:nx_cooking/data/cooking_plan/cooking_plan_attr_keys.dart';
import 'package:nx_cooking/data/cooking_plan/cooking_plan_mapper.dart';
import 'package:nx_cooking/domain/meal_status.dart';

void main() {
  group('cooking plan mapper', () {
    test('uses scheduled start and planning status from Cooking', () {
      final weekStart = DateTime(2026, 7, 6);
      final recipe = Model(
        id: 10,
        name: 'Udon',
        modelTypeId: 2,
        relations: {
          'Item': [Model(id: 20, name: 'Noodles', modelTypeId: 3)],
        },
      );
      final plan = Model(
        id: 1,
        name: 'Udon · Jul 8',
        modelTypeId: 1,
        attributes: const {
          kCookingAttrScheduledStartTime: '2026-07-08T00:00:00',
          kCookingAttrPlanningStatus: kCookingPlanningStatusPlanned,
        },
        relations: {
          'Recipe': [recipe],
        },
        relationsList: [
          Relation(
            relationId: 99,
            modelId: 10,
            modelType: 'Recipe',
            relationAttributes: const {
              kCooksRecipeRelationAttrIngredientChecks: {'20': true},
            },
          ),
        ],
      );

      final sections = buildWeekSections(
        weekStartMondayLocal: weekStart,
        plans: [plan],
      );

      final meal = sections[2].meal!;
      expect(meal.planId, 1);
      expect(meal.kind, MealCardKind.planned);
      expect(meal.badge, '1/1 items');
    });

    test('defaults missing planning status to attended', () {
      final recipe = Model(id: 10, name: 'Soup', modelTypeId: 2);
      final plan = Model(
        id: 1,
        name: 'Soup · Jul 8',
        modelTypeId: 1,
        attributes: const {
          kCookingAttrScheduledStartTime: '2026-07-08T00:00:00',
        },
        relations: {
          'Recipe': [recipe],
        },
        relationsList: [
          Relation(relationId: 99, modelId: 10, modelType: 'Recipe'),
        ],
      );

      final detail = cookingPlanDetailFromModel(plan)!;

      expect(detail.status, kCookingPlanningStatusAttended);
    });
  });
}
