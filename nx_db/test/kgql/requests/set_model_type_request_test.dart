@Tags(['unit'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/kgql.dart';
import 'package:test/test.dart' show Tags;

void main() {
  group('RT SetModelTypeRequest', () {
    test('RT6.1 minimal create', () {
      final r = SetModelTypeRequest(
        name: 'Thing',
        typeKind: 'base',
      );
      final j = r.toJson();
      expect(j['name'], 'Thing');
      expect(j['type_kind'], 'base');
    });

    test('RT6.2 ParentLink fromName', () {
      final r = SetModelTypeRequest(
        name: 'Child',
        typeKind: 'base',
        parent: ParentLink.fromName('ParentType'),
      );
      expect(r.toJson()['parent'], {'link': 'ParentType'});
    });

    test('RT6.3 attribute_definitions', () {
      final r = SetModelTypeRequest(
        name: 'X',
        typeKind: 'base',
        attributeDefinitions: [
          AttributeDefinition(key: 'title', valueType: 'string', required: true),
        ],
      );
      expect(r.toJson()['attribute_definitions'], isA<List>());
    });

    test('RT6.4 relationship_types', () {
      final r = SetModelTypeRequest(
        name: 'X',
        typeKind: 'base',
        relationshipTypes: [
          RelationshipType.fromName('Company'),
        ],
      );
      expect(r.toJson()['relationship_types'], isA<List>());
    });

    test('RT6.5 AttributeDefinition delete', () {
      final r = SetModelTypeRequest(
        name: 'X',
        typeKind: 'base',
        attributeDefinitions: [
          AttributeDefinition(id: 3, key: 'k', valueType: 'string', delete: true),
        ],
      );
      expect((r.toJson()['attribute_definitions'] as List).first, {
        'id': 3,
        'delete': true,
      });
    });
  });
}
