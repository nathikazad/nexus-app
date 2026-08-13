@Tags(['unit'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/kgql.dart';
import 'package:test/test.dart' show Tags;

void main() {
  group('buildKgqlStructFromSchema', () {
    test('attrs only: includes extraTopLevel and attribute keys', () {
      final schema = ModelType(
        id: 1,
        name: 'T',
        attributes: [
          AttributeDefinition(key: 'amount', valueType: 'number'),
          AttributeDefinition(key: 'note', valueType: 'string'),
        ],
      );
      final s = buildKgqlStructFromSchema(schema);
      expect(s['id'], true);
      expect(s['name'], true);
      expect(s['amount'], true);
      expect(s['note'], true);
      expect(s['relations'], isA<Map>());
      expect(s['model_type'], isA<Map>());
    });

    test('relations only: relation link keys map to id/name sub-struct', () {
      final schema = ModelType(
        id: 1,
        name: 'T',
        relations: [
          RelationshipType(link: 'company'),
          RelationshipType(link: '  vendor  '),
        ],
      );
      final s = buildKgqlStructFromSchema(schema);
      expect(s['company'], {'id': true, 'name': true});
      expect(s['vendor'], {'id': true, 'name': true});
    });

    test('attrs and relations together', () {
      final schema = ModelType(
        id: 1,
        name: 'T',
        attributes: [AttributeDefinition(key: 'x', valueType: 'string')],
        relations: [RelationshipType(link: 'parent')],
      );
      final s = buildKgqlStructFromSchema(schema);
      expect(s['x'], true);
      expect(s['parent'], {'id': true, 'name': true});
    });

    test('includeRelationsNode: false omits relations node', () {
      final schema = ModelType(
        id: 1,
        name: 'T',
        attributes: [AttributeDefinition(key: 'a', valueType: 'string')],
      );
      final s = buildKgqlStructFromSchema(schema, includeRelationsNode: false);
      expect(s.containsKey('relations'), isFalse);
    });

    test('includeModelTypeMeta: false omits model_type node', () {
      final schema = ModelType(id: 1, name: 'T');
      final s = buildKgqlStructFromSchema(schema, includeModelTypeMeta: false);
      expect(s.containsKey('model_type'), isFalse);
    });

    test('custom extraTopLevel replaces default keys', () {
      final schema = ModelType(id: 1, name: 'T');
      final s = buildKgqlStructFromSchema(
        schema,
        extraTopLevel: const ['id', 'custom'],
      );
      expect(s['id'], true);
      expect(s['custom'], true);
      expect(s.containsKey('name'), isFalse);
    });

    test('relation with null or blank link is skipped', () {
      final schema = ModelType(
        id: 1,
        name: 'T',
        relations: [
          RelationshipType(link: null),
          RelationshipType(link: '   '),
        ],
      );
      final s = buildKgqlStructFromSchema(schema);
      expect(
          s.keys.where((k) =>
              k != 'relations' &&
              k != 'model_type' &&
              k != 'id' &&
              k != 'name' &&
              k != 'description' &&
              k != 'created_at' &&
              k != 'model_type_id'),
          isEmpty);
    });

    test('non-String link uses toString as key', () {
      final schema = ModelType(
        id: 1,
        name: 'T',
        relations: [RelationshipType(link: 99)],
      );
      final s = buildKgqlStructFromSchema(schema);
      expect(s['99'], {'id': true, 'name': true});
    });

    test('empty schema: only defaults and optional nodes', () {
      final schema = ModelType(id: 1, name: 'T', attributes: [], relations: []);
      final s = buildKgqlStructFromSchema(schema);
      expect(s['id'], true);
      expect(s['relations'], isA<Map>());
      expect(s['model_type'], isA<Map>());
    });
  });
}
