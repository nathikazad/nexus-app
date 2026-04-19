import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_voice_assistant/data/schema/schema_entity_mappers.dart';
import 'package:nexus_voice_assistant/domain/schema/attribute_definition_draft.dart';
import 'package:nexus_voice_assistant/domain/schema/relation_definition_draft.dart';
import 'package:nexus_voice_assistant/domain/schema/schema_model_type.dart';
import 'package:nx_db/nx_db.dart' as nx;

void main() {
  group('attribute drafts', () {
    test('round-trip nx ↔ domain', () {
      final nxAttr = nx.AttributeDefinition(
        id: 1,
        key: 'age',
        valueType: 'number',
        required: true,
        constraints: const {'min': 0},
        delete: false,
      );
      final d = attributeDraftFromNx(nxAttr);
      expect(d.id, 1);
      expect(d.key, 'age');
      expect(d.valueType, 'number');
      expect(d.required, true);
      expect(d.constraints, const {'min': 0});
      final back = attributeDraftToNx(d);
      expect(back.id, nxAttr.id);
      expect(back.key, nxAttr.key);
      expect(back.valueType, nxAttr.valueType);
    });
  });

  group('relation drafts', () {
    test('round-trip with relation attributes', () {
      final nxRel = nx.RelationshipType(
        id: 2,
        link: 'Company',
        multiplicity: 'many',
        description: 'works at',
        relationAttributeDefinitions: [
          nx.RelationAttributeDefinition(
            id: 9,
            key: 'since',
            valueType: 'datetime',
            required: false,
          ),
        ],
      );
      final d = relationDraftFromNx(nxRel);
      expect(d.link, 'Company');
      expect(d.relationAttributeDefinitions?.length, 1);
      expect(d.relationAttributeDefinitions!.first.key, 'since');
      final back = relationDraftToNx(d);
      expect(back.link, nxRel.link);
      expect(back.relationAttributeDefinitions?.length, 1);
    });
  });

  group('schemaModelTypeFromNx', () {
    test('maps nested parent and children', () {
      final child = nx.ModelType(id: 2, name: 'Child', parentId: 1);
      final parent = nx.ModelType(
        id: 1,
        name: 'Parent',
        children: [child],
      );
      final s = schemaModelTypeFromNx(parent);
      expect(s.id, 1);
      expect(s.children?.length, 1);
      expect(s.children!.first.name, 'Child');
    });

    test('maps tag systems', () {
      final mt = nx.ModelType(
        id: 1,
        name: 'T',
        tagSystems: [
          nx.TagSystem(
            id: 10,
            name: 'labels',
            isHierarchical: false,
            selectionMode: 'multiple',
          ),
        ],
      );
      final s = schemaModelTypeFromNx(mt);
      expect(s.tagSystems?.length, 1);
      expect(s.tagSystems!.first.name, 'labels');
    });
  });

  group('schemaModelFromNx', () {
    test('maps relations map and model type', () {
      final related = nx.Model(id: 9, name: 'R', modelTypeId: 2);
      final m = nx.Model(
        id: 1,
        name: 'Alice',
        modelTypeId: 1,
        relations: {
          'Company': [related],
        },
        modelType: nx.ModelType(id: 1, name: 'Person'),
      );
      final s = schemaModelFromNx(m);
      expect(s.relations?.length, 1);
      expect(s.relations!['Company']!.first.id, 9);
      expect(s.modelType?.name, 'Person');
    });
  });

  group('ModelTypeFormFields path', () {
    test('SchemaModelType preserves drafts through domain factory', () {
      final mt = SchemaModelType(
        id: 3,
        name: 'X',
        typeKind: 'base',
        description: 'd',
        attributes: const [
          AttributeDefinitionDraft(id: 1, key: 'k', valueType: 'string'),
        ],
        relations: const [
          RelationDefinitionDraft(id: 2, link: 'Y'),
        ],
      );
      expect(mt.attributes!.length, 1);
      expect(mt.relations!.first.link, 'Y');
    });
  });
}
