import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/nx_db.dart';
import 'package:nx_expense/expense_schema.dart';

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
      final ts = tagSystemByName(mt, 'Judgment');
      expect(ts, isNotNull);
      expect(ts!.name, 'Judgment');
    });

    test('H6.5 tagSystemByName missing', () {
      final mt = ModelType.fromJson({'id': 1, 'name': 'Expense'});
      expect(tagSystemByName(mt, 'Nope'), isNull);
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
      expect(allRelationTargetTypeNames(mt), {'Company', 'Place'});
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
      final d = filterChipDescriptors(mt);
      expect(d.length, 2);
      expect(d.map((e) => e.label).toSet(), {'Food', 'Travel'});
    });
  });
}
