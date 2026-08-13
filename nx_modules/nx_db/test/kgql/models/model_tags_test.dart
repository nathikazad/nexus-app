@Tags(['unit'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/kgql.dart';
import 'package:test/test.dart' show Tags;

void main() {
  group('Model tags', () {
    test('M3.1 tags map', () {
      final m = Model.fromJson({
        'id': 1,
        'name': 'Coffee',
        'model_type_id': 9,
        'tags': {
          'Category': ['Coffee'],
          'Judgment': ['Unnecessary'],
        },
      });
      expect(m.tags?['Category'], ['Coffee']);
      expect(m.tags?['Judgment'], ['Unnecessary']);
    });

    test('M3.2 empty tag list', () {
      final m = Model.fromJson({
        'id': 1,
        'name': 'X',
        'model_type_id': 9,
        'tags': {'Category': []},
      });
      expect(m.tags?['Category'], isEmpty);
    });

    test('M3.3 no tags key', () {
      final m = Model.fromJson({
        'id': 1,
        'name': 'X',
        'model_type_id': 9,
      });
      expect(m.tags, isNull);
    });

    test('M3.4 coexists with top-level cost', () {
      final m = Model.fromJson({
        'id': 1,
        'name': 'X',
        'model_type_id': 9,
        'cost': 12.5,
        'tags': {
          'Category': ['Coffee']
        },
      });
      expect(m.id, 1);
      expect(m.tags?['Category'], ['Coffee']);
      expect(m.attributes?['cost'], 12.5);
    });
  });
}
