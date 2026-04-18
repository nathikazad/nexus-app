@Tags(['unit'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/nx_db.dart';
import 'package:test/test.dart' show Tags;

void main() {
  group('MD Model', () {
    test('MD1.1 identity + model_type_id', () {
      final m = Model.fromJson({
        'id': 1,
        'name': 'A',
        'model_type_id': 9,
      });
      expect(m.id, 1);
      expect(m.name, 'A');
      expect(m.modelTypeId, 9);
    });

    test('MD1.2 camelCase modelTypeId', () {
      final m = Model.fromJson({
        'id': 1,
        'name': 'A',
        'modelTypeId': 9,
      });
      expect(m.modelTypeId, 9);
    });

    test('MD1.3 timestamps', () {
      final m = Model.fromJson({
        'id': 1,
        'name': 'A',
        'model_type_id': 9,
        'created_at': '2025-01-01T00:00:00Z',
        'updated_at': '2025-01-02T00:00:00Z',
      });
      expect(m.createdAt, '2025-01-01T00:00:00Z');
      expect(m.updatedAt, '2025-01-02T00:00:00Z');
    });

    test('MD1.4 attributes as array', () {
      final m = Model.fromJson({
        'id': 1,
        'name': 'A',
        'model_type_id': 9,
        'attributes': [
          {'id': 10, 'key': 'k', 'value': 'v'},
        ],
      });
      expect(m.attributesList, isNotNull);
      expect(m.attributesList!.length, 1);
      expect(m.attributesList!.first.key, 'k');
      expect(m.attributes!['k'], 'v');
    });

    test('MD1.5 attributes as map', () {
      final m = Model.fromJson({
        'id': 1,
        'name': 'A',
        'model_type_id': 9,
        'attributes': {'x': 'y'},
      });
      expect(m.attributes, {'x': 'y'});
    });

    test('MD1.6 legacy flat keys', () {
      final m = Model.fromJson({
        'id': 1,
        'name': 'A',
        'model_type_id': 9,
        'cost': 12.5,
      });
      expect(m.attributes?['cost'], 12.5);
    });

    test('MD1.7 relations array', () {
      final m = Model.fromJson({
        'id': 1,
        'name': 'A',
        'model_type_id': 9,
        'relations': [
          {
            'relation_id': 100,
            'model_id': 2,
            'model_type': 'Company',
            'name': 'Acme',
          },
        ],
      });
      expect(m.relationsList?.length, 1);
      expect(m.relationsList!.first.modelType, 'Company');
    });

    test('MD1.8 type-specific Company relation', () {
      final m = Model.fromJson({
        'id': 1,
        'name': 'E',
        'model_type_id': 9,
        'Company': [
          {
            'id': 2,
            'name': 'Acme',
            'model_type_id': 3,
          },
        ],
      });
      expect(m.relations?['Company']?.length, 1);
      expect(m.relations!['Company']!.first.name, 'Acme');
    });

    test('MD1.10 toJson smoke', () {
      final m = Model.fromJson({
        'id': 1,
        'name': 'A',
        'model_type_id': 9,
      });
      final j = m.toJson();
      expect(j['id'], 1);
      expect(j['name'], 'A');
      expect(j['modelTypeId'], 9);
    });

    test('MD1.11 relationsByModelType', () {
      final m = Model.fromJson({
        'id': 1,
        'name': 'A',
        'model_type_id': 9,
        'relations': [
          {'relation_id': 1, 'model_id': 10, 'model_type': 'Company'},
          {'relation_id': 2, 'model_id': 11, 'model_type': 'Place'},
          {'relation_id': 3, 'model_id': 12, 'model_type': 'Company'},
        ],
      });
      final g = m.relationsByModelType;
      expect(g.keys.toSet(), {'Company', 'Place'});
      expect(g['Company']!.length, 2);
      expect(g['Place']!.length, 1);
    });

    test('E14.1 extra keys ignored for identity', () {
      final m = Model.fromJson({
        'id': 1,
        'name': 'A',
        'model_type_id': 9,
        'future_field_xyz': 123,
      });
      expect(m.id, 1);
    });

    test('E14.2 deep type-specific relation chain', () {
      final m = Model.fromJson({
        'id': 1,
        'name': 'Root',
        'model_type_id': 9,
        'Company': [
          {
            'id': 2,
            'name': 'L1',
            'model_type_id': 3,
            'Person': [
              {'id': 3, 'name': 'L2', 'model_type_id': 4},
            ],
          },
        ],
      });
      expect(m.relations!['Company']!.first.relations?['Person']?.first.name, 'L2');
    });

    test('MD1.12 description as list (root model)', () {
      final m = Model.fromJson({
        'id': 1,
        'name': 'E',
        'model_type_id': 9,
        'description': ['line one', 'line two'],
      });
      expect(m.description, 'line one\nline two');
    });

    test('MD1.13 description as list on nested relation model', () {
      final m = Model.fromJson({
        'id': 1,
        'name': 'Expense',
        'model_type_id': 9,
        'Transfer': [
          {
            'id': 2,
            'name': 'Wire',
            'model_type_id': 5,
            'description': ['Memo a', 'Memo b'],
          },
        ],
      });
      expect(m.relations!['Transfer']!.first.description, 'Memo a\nMemo b');
    });

    test('MD1.14 embedded model_type from get_kgql_models', () {
      final m = Model.fromJson({
        'id': 1,
        'name': 'Nap',
        'model_type_id': 12,
        'model_type': {
          'id': 12,
          'name': 'Sleep',
          'type_kind': 'concrete',
        },
      });
      expect(m.modelType, isNotNull);
      expect(m.modelType!.name, 'Sleep');
      expect(m.modelType!.id, 12);
    });
  });
}
