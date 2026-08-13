@Tags(['unit'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/kgql.dart';
import 'package:test/test.dart' show Tags;

void main() {
  group('RS SetModelRequest', () {
    test('RS5.1 minimal create', () {
      final r = SetModelRequest(
        modelType: 'Expense',
        name: 'Coffee',
        attributes: [
          SetModelAttribute(key: 'cost', value: 3),
        ],
      );
      final j = r.toJson();
      expect(j['model_type'], 'Expense');
      expect(j['name'], 'Coffee');
      expect(j['attributes'], isA<List>());
    });

    test('RS5.2 update with id', () {
      final r = SetModelRequest(id: 99, name: 'X');
      expect(r.toJson()['id'], 99);
    });

    test('serializes top-level suggestion and meta JSON', () {
      final r = SetModelRequest(
        id: 99,
        suggestion: {
          'work': [
            {'company': 'Example Corp'},
          ],
        },
        meta: {
          'linked_in': {'hash': 'abc123'},
        },
      );

      expect(r.toJson(), {
        'id': 99,
        'suggestion': {
          'work': [
            {'company': 'Example Corp'},
          ],
        },
        'meta': {
          'linked_in': {'hash': 'abc123'},
        },
      });
    });

    test('RS5.3 SetModelAttribute delete', () {
      final r = SetModelRequest(
        attributes: [SetModelAttribute(key: 'age', delete: true)],
      );
      expect(r.toJson()['attributes'], [
        {'key': 'age', 'delete': true},
      ]);
    });

    test('RS5.4 ModelRelation link', () {
      final r = SetModelRequest(
        relations: [
          ModelRelation(
            modelType: 'Company',
            relationName: 'work_for',
            link: [1, 2],
          ),
        ],
      );
      expect(r.toJson()['relations'], [
        {
          'model_type': 'Company',
          'relation_name': 'work_for',
          'link': [1, 2],
        },
      ]);
    });

    test('RS5.5 ModelRelation delete', () {
      final r = SetModelRequest(
        relations: [
          ModelRelation(id: 5, delete: true),
        ],
      );
      final jr = (r.toJson()['relations'] as List).first as Map;
      expect(jr['id'], 5);
      expect(jr['delete'], true);
    });

    test('RS5.6 RelationAttribute on relation', () {
      final r = SetModelRequest(
        relations: [
          ModelRelation(
            modelType: 'Company',
            link: [1],
            attributes: [
              RelationAttribute(key: 'role', value: 'primary'),
            ],
          ),
        ],
      );
      final rel =
          (r.toJson()['relations'] as List).first as Map<String, dynamic>;
      expect(rel['attributes'], [
        {'key': 'role', 'value': 'primary'},
      ]);
    });
  });
}
