@Tags(['unit'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/kgql.dart';

void main() {
  group('MT ModelType', () {
    test('MT2.1 flat root', () {
      final mt = ModelType.fromJson({
        'id': 1,
        'name': 'Person',
        'type_kind': 'base',
      });
      expect(mt.typeKind, 'base');
    });

    test('MT2.2 snake and camel type_kind', () {
      final a = ModelType.fromJson({'id': 1, 'name': 'X', 'type_kind': 'base'});
      final b = ModelType.fromJson({'id': 1, 'name': 'X', 'typeKind': 'mixin'});
      expect(a.typeKind, 'base');
      expect(b.typeKind, 'mixin');
    });

    test('MT2.3 parent node', () {
      final mt = ModelType.fromJson({
        'id': 2,
        'name': 'Child',
        'parent': {'id': 1, 'name': 'Parent'},
      });
      expect(mt.parent, isNotNull);
      expect(mt.parent!.id, 1);
      expect(mt.parentId, 1);
    });

    test('MT2.4 children recursive', () {
      final mt = ModelType.fromJson({
        'id': 1,
        'name': 'Root',
        'children': [
          {'id': 10, 'name': 'C1'},
        ],
      }, recursive: true);
      expect(mt.children?.length, 1);
      expect(mt.children!.first.parentId, 1);
      expect(mt.children!.first.name, 'C1');
    });

    test('MT2.5 mixins', () {
      final mt = ModelType.fromJson({
        'id': 1,
        'name': 'Base',
        'mixins': [
          {'id': 20, 'name': 'Plannable'},
        ],
      }, recursive: true);
      expect(mt.mixins?.length, 1);
      expect(mt.mixins!.first.parentId, 1);
      expect(mt.traits, mt.mixins);
    });

    test('MT2.5b legacy traits alias parses as mixins', () {
      final mt = ModelType.fromJson({
        'id': 1,
        'name': 'Base',
        'traits': [
          {'id': 20, 'name': 'Legacy'},
        ],
      }, recursive: true);
      expect(mt.mixins?.length, 1);
      expect(mt.mixins!.first.name, 'Legacy');
      expect(mt.traits, mt.mixins);
    });

    test('MT2.6 attributes', () {
      final mt = ModelType.fromJson({
        'id': 1,
        'name': 'X',
        'attributes': [
          {'key': 'age', 'value_type': 'number', 'required': true},
        ],
      });
      expect(mt.attributes?.length, 1);
      expect(mt.attributes!.first.key, 'age');
      expect(mt.attributes!.first.valueType, 'number');
    });

    test('MT2.7 relations target_model_type', () {
      final mt = ModelType.fromJson({
        'id': 1,
        'name': 'X',
        'relations': [
          {
            'target_model_type': 'Company',
            'attributes': [],
          },
        ],
      });
      expect(mt.relations?.length, 1);
      expect(mt.relations!.first.link, 'Company');
    });

    test('MT2.9 toJson smoke', () {
      final mt = ModelType.fromJson({
        'id': 7,
        'name': 'Expense',
        'agent_instructions': {'Expense': 'Use merchant lookup.'},
        'attributes': [
          {'key': 'cost', 'value_type': 'number'},
        ],
      });
      final j = mt.toJson();
      expect(j['id'], 7);
      expect(j['name'], 'Expense');
      expect(mt.agentInstructions, {'Expense': 'Use merchant lookup.'});
      expect(j['agent_instructions'], {'Expense': 'Use merchant lookup.'});
      expect(j['attributes'], isNotNull);
    });

    test('MT2.10 AttributeDefinition delete toJson', () {
      final ad = AttributeDefinition(
          id: 5, key: 'x', valueType: 'string', delete: true);
      expect(ad.toJson(), {'id': 5, 'delete': true});
    });

    test('MT2.11 RelationshipType delete toJson', () {
      final rt = RelationshipType(id: 9, link: 'X', delete: true);
      expect(rt.toJson(), {'id': 9, 'delete': true});
    });

    test('MT2.12 relation_attribute_definitions', () {
      final rt = RelationshipType.fromName(
        'Company',
        relationAttributeDefinitions: [
          RelationAttributeDefinition(key: 'role', valueType: 'string'),
        ],
      );
      final j = rt.toJson();
      expect(j['relation_attribute_definitions'], isA<List>());
      expect((j['relation_attribute_definitions'] as List).length, 1);
    });
  });
}
