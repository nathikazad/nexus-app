@Tags(['unit'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/kgql.dart';
import 'package:test/test.dart' show Tags;

void main() {
  group('E10 tags / TagNode edge cases', () {
    test('E10.1 malformed tags value — non-list coerces to empty list for that key', () {
      final m = Model.fromJson({
        'id': 1,
        'name': 'X',
        'model_type_id': 9,
        'tags': {
          'Category': 'not-a-list',
        },
      });
      expect(m.tags?['Category'], isEmpty);
    });

    test('E10.2 very deep tag tree (4 levels)', () {
      final n = TagNode.fromJson({
        'id': 1,
        'name': 'L1',
        'children': [
          {
            'id': 2,
            'name': 'L2',
            'children': [
              {
                'id': 3,
                'name': 'L3',
                'children': [
                  {'id': 4, 'name': 'L4'},
                ],
              },
            ],
          },
        ],
      });
      expect(n.leafNames, ['L4']);
    });

    test('E10.3 unicode and spaces in node name round-trip', () {
      const name = 'Café ☕';
      final n = TagNode.fromJson({'id': 1, 'name': name});
      expect(n.name, name);
      expect(n.toJson()['name'], name);
    });
  });
}
