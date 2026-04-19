import 'relation_attribute_definition_draft.dart';

/// Relationship type row for model-type create/edit (pure Dart).
///
/// [link] is a target model type id ([int]) or name ([String]), matching KGQL.
class RelationDefinitionDraft {
  final int? id;
  final Object? link;
  final String? multiplicity;
  final String? description;
  final List<RelationAttributeDefinitionDraft>? relationAttributeDefinitions;
  final bool delete;

  const RelationDefinitionDraft({
    this.id,
    this.link,
    this.multiplicity,
    this.description,
    this.relationAttributeDefinitions,
    this.delete = false,
  });
}
