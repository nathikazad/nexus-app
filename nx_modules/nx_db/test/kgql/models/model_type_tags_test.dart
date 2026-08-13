@Tags(['unit'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/kgql.dart';
import 'package:test/test.dart' show Tags;

void main() {
  group('ModelType tag_systems', () {
    test('M2.1 parses tag_systems array', () {
      final mt = ModelType.fromJson({
        'id': 9,
        'name': 'Expense',
        'tag_systems': [
          {
            'id': 1,
            'name': 'Category',
            'is_hierarchical': true,
            'selection_mode': 'exclusive',
            'nodes': [],
          },
          {
            'id': 2,
            'name': 'Judgment',
            'is_hierarchical': false,
            'selection_mode': 'multiple',
            'nodes': [],
          },
        ],
      });
      expect(mt.tagSystems, isNotNull);
      expect(mt.tagSystems!.length, 2);
      expect(mt.tagSystems!.first.name, 'Category');
    });

    test('M2.2 no tag_systems key', () {
      final mt = ModelType.fromJson({
        'id': 1,
        'name': 'Expense',
      });
      expect(mt.tagSystems, isNull);
    });

    test('M2.3 tag_systems null', () {
      final mt = ModelType.fromJson({
        'id': 1,
        'name': 'Expense',
        'tag_systems': null,
      });
      expect(mt.tagSystems, isNull);
    });
  });
}
