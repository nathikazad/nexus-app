import 'package:nexus_voice_assistant/domain/schema/schema_model_list_query.dart';
import 'package:nx_db/nx_db.dart' as nx;

import 'package:nexus_voice_assistant/domain/schema/attribute_definition_draft.dart';
import 'package:nexus_voice_assistant/domain/schema/relation_attribute_definition_draft.dart';
import 'package:nexus_voice_assistant/domain/schema/relation_definition_draft.dart';
import 'package:nexus_voice_assistant/domain/schema/schema_model.dart';
import 'package:nexus_voice_assistant/domain/schema/schema_model_attribute.dart';
import 'package:nexus_voice_assistant/domain/schema/schema_model_type.dart';
import 'package:nexus_voice_assistant/domain/schema/schema_relation.dart';
import 'package:nexus_voice_assistant/domain/schema/schema_tag_system_summary.dart';

AttributeDefinitionDraft attributeDraftFromNx(nx.AttributeDefinition a) {
  return AttributeDefinitionDraft(
    id: a.id,
    key: a.key,
    valueType: a.valueType,
    required: a.required,
    constraints: a.constraints,
    delete: a.delete,
  );
}

nx.AttributeDefinition attributeDraftToNx(AttributeDefinitionDraft d) {
  return nx.AttributeDefinition(
    id: d.id,
    key: d.key,
    valueType: d.valueType,
    required: d.required,
    constraints: d.constraints,
    delete: d.delete,
  );
}

RelationAttributeDefinitionDraft relationAttrDraftFromNx(
  nx.RelationAttributeDefinition a,
) {
  return RelationAttributeDefinitionDraft(
    id: a.id,
    key: a.key,
    valueType: a.valueType,
    required: a.required,
  );
}

nx.RelationAttributeDefinition relationAttrDraftToNx(
  RelationAttributeDefinitionDraft d,
) {
  return nx.RelationAttributeDefinition(
    id: d.id,
    key: d.key,
    valueType: d.valueType,
    required: d.required,
  );
}

RelationDefinitionDraft relationDraftFromNx(nx.RelationshipType r) {
  return RelationDefinitionDraft(
    id: r.id,
    link: r.link,
    multiplicity: r.multiplicity,
    description: r.description,
    relationAttributeDefinitions:
        r.relationAttributeDefinitions?.map(relationAttrDraftFromNx).toList(),
    delete: r.delete,
  );
}

nx.RelationshipType relationDraftToNx(RelationDefinitionDraft d) {
  return nx.RelationshipType(
    id: d.id,
    link: d.link,
    multiplicity: d.multiplicity,
    description: d.description,
    relationAttributeDefinitions:
        d.relationAttributeDefinitions?.map(relationAttrDraftToNx).toList(),
    delete: d.delete,
  );
}

SchemaTagSystemSummary tagSystemFromNx(nx.TagSystem t) {
  return SchemaTagSystemSummary(
    id: t.id,
    name: t.name,
    isHierarchical: t.isHierarchical,
    selectionMode: t.selectionMode,
  );
}

SchemaModelType schemaModelTypeFromNx(nx.ModelType m) {
  return SchemaModelType(
    id: m.id,
    name: m.name,
    typeKind: m.typeKind,
    description: m.description,
    agentInstructions: m.agentInstructions,
    parentId: m.parentId,
    userId: m.userId,
    parent: m.parent != null ? schemaModelTypeFromNx(m.parent!) : null,
    children: m.children?.map(schemaModelTypeFromNx).toList(),
    mixins: m.mixins?.map(schemaModelTypeFromNx).toList(),
    attributes: m.attributes?.map(attributeDraftFromNx).toList(),
    relations: m.relations?.map(relationDraftFromNx).toList(),
    tagSystems: m.tagSystems?.map(tagSystemFromNx).toList(),
  );
}

SchemaModelAttribute schemaModelAttributeFromNx(nx.ModelAttribute a) {
  return SchemaModelAttribute(
    id: a.id,
    key: a.key,
    value: a.value,
  );
}

SchemaRelation schemaRelationFromNx(nx.Relation r) {
  return SchemaRelation(
    relationId: r.relationId,
    modelId: r.modelId,
    modelType: r.modelType,
    name: r.name,
    description: r.description,
    relation: r.relation,
    relationAttributes: r.relationAttributes,
  );
}

SchemaModel schemaModelFromNx(nx.Model m) {
  return SchemaModel(
    id: m.id,
    name: m.name,
    description: m.description,
    modelTypeId: m.modelTypeId,
    createdAt: m.createdAt,
    updatedAt: m.updatedAt,
    attributes: m.attributes,
    attributesList: m.attributesList?.map(schemaModelAttributeFromNx).toList(),
    relations: m.relations?.map(
      (k, v) => MapEntry(k, v.map(schemaModelFromNx).toList()),
    ),
    relationsList: m.relationsList?.map(schemaRelationFromNx).toList(),
    tags: m.tags,
    modelType: m.modelType != null ? schemaModelTypeFromNx(m.modelType!) : null,
  );
}

/// Translate app query semantics at the database boundary, including the extra
/// row used to detect whether another page exists.
nx.ModelListQuery schemaModelListQueryToNx(SchemaModelListQuery query) {
  return nx.ModelListQuery(
    modelTypeId: query.modelTypeId,
    search: query.search,
    filters: query.filters
        .map((filter) => nx.ModelListFilter(
              key: filter.key,
              op: filter.operator.kgqlOp,
              value: filter.operator == SchemaModelFilterOperator.like
                  ? '%${filter.value}%'
                  : filter.value,
            ))
        .toList(),
    sort: query.sort == null
        ? null
        : nx.ModelListSort(
            key: query.sort!.key, descending: query.sort!.descending),
    limit: schemaModelListPageSize + 1,
    offset: query.offset,
  );
}
