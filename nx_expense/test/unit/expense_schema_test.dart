import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/nx_db.dart';
import 'package:nx_expense/data/expense/expense_struct.dart';
import 'package:nx_expense/data/schema/kgql_schema_helpers.dart';
import 'package:nx_expense/data/schema/model_type_view_mapper.dart';
import 'package:nx_expense/domain/schema/model_type_view.dart';
import 'package:nx_expense/features/expense/widgets/relation_picker.dart';

void main() {
  group('buildExpenseStruct', () {
    test('S5.1 attributes only', () {
      final mt = ModelType.fromJson({
        'id': 1,
        'name': 'Expense',
        'attributes': [
          {'key': 'cost', 'value_type': 'number'},
          {'key': 'note', 'value_type': 'string'},
        ],
      });
      final s = buildExpenseStruct(mt);
      expect(s['cost'], true);
      expect(s['note'], true);
    });

    test('S5.2 relations', () {
      final mt = ModelType.fromJson({
        'id': 1,
        'name': 'Expense',
        'relations': [
          {'target_model_type': 'Company'},
        ],
      });
      final s = buildExpenseStruct(mt);
      expect(s['Company'], {'id': true, 'name': true});
    });

    test('S5.3 tags shorthand', () {
      final mt = ModelType.fromJson({'id': 1, 'name': 'Expense'});
      final s = buildExpenseStruct(mt);
      expect(s['tags'], true);
    });

    test('S5.4 base fields', () {
      final mt = ModelType.fromJson({'id': 1, 'name': 'Expense'});
      final s = buildExpenseStruct(mt);
      expect(s['id'], true);
      expect(s['name'], true);
      expect(s['description'], true);
      expect(s['created_at'], true);
    });

    test('S5.5 empty attributes', () {
      final mt = ModelType.fromJson({
        'id': 1,
        'name': 'Expense',
        'attributes': [],
      });
      final s = buildExpenseStruct(mt);
      expect(s.containsKey('cost'), false);
      expect(s['tags'], true);
    });

    test('S5.6 determinism', () {
      final mt = ModelType.fromJson({
        'id': 1,
        'name': 'Expense',
        'attributes': [
          {'key': 'a', 'value_type': 'string'},
          {'key': 'b', 'value_type': 'number'},
        ],
      });
      final a = buildExpenseStruct(mt);
      final b = buildExpenseStruct(mt);
      expect(a, b);
    });
  });

  group('schema helpers', () {
    test('H6.1 primary number key', () {
      final mt = ModelType.fromJson({
        'id': 1,
        'name': 'Expense',
        'attributes': [
          {'key': 'age', 'value_type': 'string'},
          {'key': 'cost', 'value_type': 'number'},
        ],
      });
      expect(primaryNumberAttributeKey(mt), 'cost');
    });

    test('H6.2 no number', () {
      final mt = ModelType.fromJson({
        'id': 1,
        'name': 'Expense',
        'attributes': [
          {'key': 'note', 'value_type': 'string'},
        ],
      });
      expect(primaryNumberAttributeKey(mt), isNull);
    });

    test('H6.3 first number wins', () {
      final mt = ModelType.fromJson({
        'id': 1,
        'name': 'Expense',
        'attributes': [
          {'key': 'a', 'value_type': 'number'},
          {'key': 'b', 'value_type': 'number'},
        ],
      });
      expect(primaryNumberAttributeKey(mt), 'a');
    });

    test('H6.4 tagSystemByName', () {
      final mt = ModelType.fromJson({
        'id': 1,
        'name': 'Expense',
        'tag_systems': [
          {
            'id': 1,
            'name': 'Judgment',
            'is_hierarchical': false,
            'selection_mode': 'multiple',
            'nodes': [],
          },
        ],
      });
      final view = modelTypeViewFromKgql(mt);
      final ts = tagSystemByName(view, 'Judgment');
      expect(ts, isNotNull);
      expect(ts!.name, 'Judgment');
    });

    test('H6.5 tagSystemByName missing', () {
      final mt = ModelType.fromJson({'id': 1, 'name': 'Expense'});
      expect(tagSystemByName(modelTypeViewFromKgql(mt), 'Nope'), isNull);
    });

    test('H6.6 allRelationTargetTypeNames', () {
      final mt = ModelType.fromJson({
        'id': 1,
        'name': 'Expense',
        'relations': [
          {'target_model_type': 'Company'},
          {'target_model_type': 'Place'},
        ],
      });
      expect(allRelationTargetTypeNames(modelTypeViewFromKgql(mt)), {'Company', 'Place'});
    });

    test('H6.7 filterChipDescriptors', () {
      final mt = ModelType.fromJson({
        'id': 1,
        'name': 'Expense',
        'tag_systems': [
          {
            'id': 1,
            'name': 'Category',
            'is_hierarchical': true,
            'selection_mode': 'exclusive',
            'nodes': [
              {'id': 10, 'name': 'Food'},
              {'id': 11, 'name': 'Travel'},
            ],
          },
        ],
      });
      final d = filterChipDescriptors(modelTypeViewFromKgql(mt));
      expect(d.length, 2);
      expect(d.map((e) => e.label).toSet(), {'Food', 'Travel'});
    });
  });

  group('dedupeIntIdsPreserveOrder (regression)', () {
    test('R1 removes consecutive duplicate ids', () {
      expect(dedupeIntIdsPreserveOrder([1, 1, 2, 1]), [1, 2]);
    });

    test('R2 preserves first-seen order', () {
      expect(dedupeIntIdsPreserveOrder([3, 1, 3, 2]), [3, 1, 2]);
    });

    test('R3 empty', () {
      expect(dedupeIntIdsPreserveOrder([]), isEmpty);
    });
  });

  group('dedupeModelsById (regression)', () {
    test('R4 drops duplicate model ids', () {
      final a = Model(id: 1, name: 'A', modelTypeId: 1);
      final b = Model(id: 1, name: 'A2', modelTypeId: 1);
      final out = dedupeModelsById([a, b]);
      expect(out.length, 1);
      expect(out.first.name, 'A');
    });
  });

  group('relationPendingCreateEquals (regression)', () {
    test('R5 null matches', () {
      expect(relationPendingCreateEquals(null, null), true);
      expect(relationPendingCreateEquals({'a': 1}, null), false);
    });

    test('R6 map equality', () {
      expect(
        relationPendingCreateEquals(
          {'name': 'Co', 'description': 'x'},
          {'name': 'Co', 'description': 'x'},
        ),
        true,
      );
      expect(
        relationPendingCreateEquals({'name': 'Co'}, {'name': 'Other'}),
        false,
      );
    });
  });

  group('relationStateMatchesSnapshotForUpdate (regression)', () {
    test('R7 matches when link sets equal (different Set instances)', () {
      expect(
        relationStateMatchesSnapshotForUpdate(
          linkIdsByType: {'Company': [10, 20]},
          createsByType: {'Company': null},
          snapshotLinkIdsByType: {
            'Company': {20, 10},
          },
          snapshotCreatesByType: {'Company': null},
        ),
        true,
      );
    });

    test('R8 fails when link id differs', () {
      expect(
        relationStateMatchesSnapshotForUpdate(
          linkIdsByType: {'Company': [10]},
          createsByType: {'Company': null},
          snapshotLinkIdsByType: {'Company': {99}},
          snapshotCreatesByType: {'Company': null},
        ),
        false,
      );
    });

    test('R9 duplicate ids in current list still matches snapshot set', () {
      expect(
        relationStateMatchesSnapshotForUpdate(
          linkIdsByType: {'Company': [10, 10, 20]},
          createsByType: {'Company': null},
          snapshotLinkIdsByType: {'Company': {10, 20}},
          snapshotCreatesByType: {'Company': null},
        ),
        true,
      );
    });

    test('R10 create payload change fails', () {
      expect(
        relationStateMatchesSnapshotForUpdate(
          linkIdsByType: {'Company': []},
          createsByType: {
            'Company': {'name': 'NewCo'},
          },
          snapshotLinkIdsByType: {'Company': <int>{}},
          snapshotCreatesByType: {'Company': null},
        ),
        false,
      );
    });
  });

  group('shouldOmitRelationsOnExpenseUpdate (regression)', () {
    test('R11 create flow never omits', () {
      expect(
        shouldOmitRelationsOnExpenseUpdate(
          expenseId: null,
          linkIdsByType: {'Company': [1]},
          createsByType: {'Company': null},
          snapshotLinkIdsByType: {'Company': {1}},
          snapshotCreatesByType: {'Company': null},
        ),
        false,
      );
    });

    test('R12 update omits when snapshot matches', () {
      expect(
        shouldOmitRelationsOnExpenseUpdate(
          expenseId: 42,
          linkIdsByType: {'Company': [1]},
          createsByType: {'Company': null},
          snapshotLinkIdsByType: {'Company': {1}},
          snapshotCreatesByType: {'Company': null},
        ),
        true,
      );
    });
  });

  group('RelationPickResult (regression)', () {
    test('R13 link vs create', () {
      final link = RelationPickLink([1, 2]);
      final create = RelationPickCreate({'name': 'X'});
      expect(link.ids, [1, 2]);
      expect(create.create, {'name': 'X'});
    });
  });
}
