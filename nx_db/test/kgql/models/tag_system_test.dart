@Tags(['unit'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/nx_db.dart';
import 'package:test/test.dart' show Tags;

void main() {
  group('TagSystem / TagNode', () {
    test('M1.1 flat tag system', () {
      final ts = TagSystem.fromJson({
        'id': 1,
        'name': 'Judgment',
        'is_hierarchical': false,
        'selection_mode': 'multiple',
        'nodes': [
          {'id': 10, 'name': 'A'},
          {'id': 11, 'name': 'B'},
        ],
      });
      expect(ts.isHierarchical, false);
      expect(ts.nodes.length, 2);
      expect(ts.nodes.every((n) => n.children == null), true);
    });

    test('M1.3 snake_case keys map to Dart fields', () {
      final ts = TagSystem.fromJson({
        'id': 1,
        'name': 'X',
        'is_hierarchical': true,
        'selection_mode': 'exclusive',
        'model_type_id': 99,
        'nodes': [],
      });
      expect(ts.isHierarchical, true);
      expect(ts.selectionMode, 'exclusive');
      expect(ts.modelTypeId, 99);
    });

    test('M1.2 hierarchical parse', () {
      final ts = TagSystem.fromJson({
        'id': 2,
        'name': 'Category',
        'is_hierarchical': true,
        'selection_mode': 'exclusive',
        'nodes': [
          {
            'id': 20,
            'name': 'Food',
            'children': [
              {'id': 21, 'name': 'Coffee'},
            ],
          },
        ],
      });
      expect(ts.nodes.first.children?.first.name, 'Coffee');
    });

    test('M1.4 missing model_type_id', () {
      final ts = TagSystem.fromJson({
        'id': 1,
        'name': 'X',
        'is_hierarchical': false,
        'selection_mode': 'multiple',
        'nodes': [],
      });
      expect(ts.modelTypeId, isNull);
    });

    test('M1.5 empty nodes', () {
      final ts = TagSystem.fromJson({
        'id': 1,
        'name': 'X',
        'is_hierarchical': false,
        'selection_mode': 'multiple',
        'nodes': [],
      });
      expect(ts.nodes, isEmpty);
    });

    test('M1.6 leafNames', () {
      final n = TagNode.fromJson({
        'id': 1,
        'name': 'Root',
        'children': [
          {
            'id': 2,
            'name': 'Mid',
            'children': [
              {'id': 3, 'name': 'Leaf'},
            ],
          },
        ],
      });
      expect(n.leafNames, ['Leaf']);
    });
  });
}
