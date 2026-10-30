import 'relation_attribute_definition_draft.dart';

/// Relationship type row for model-type create/edit (pure Dart).
///
/// [link] is a target model type id ([int]) or name ([String]), matching KGQL.
class RelationDefinitionDraft {
  final int? id;
  final Object? link;
  final Map<String, RelationEndpointDraft> endpoints;
  final String? relationName;
  final int? definingModelTypeId;
  String get endpointSummary => endpoints.entries
      .map((e) => '${e.key}: ${e.value.type} (${e.value.count})')
      .join(' • ');
  final String? description;
  final List<RelationAttributeDefinitionDraft>? relationAttributeDefinitions;
  final bool delete;

  const RelationDefinitionDraft({
    this.id,
    this.link,
    this.endpoints = const {},
    this.relationName,
    this.definingModelTypeId,
    this.description,
    this.relationAttributeDefinitions,
    this.delete = false,
  });
}

class RelationEndpointDraft {
  final Object type;
  final String count;
  const RelationEndpointDraft({required this.type, required this.count});
}
