import 'attribute_definition_draft.dart';
import 'relation_definition_draft.dart';

/// Persists model type create/update via KGQL (`setKgqlModelTypes`).
abstract class ModelTypeWriteRepository {
  /// Returns the saved model type id from the mutation response.
  Future<int> setModelType({
    int? id,
    required String name,
    required String typeKind,
    String? description,
    int? parentId,
    required List<AttributeDefinitionDraft> attributeDefinitions,
    required List<RelationDefinitionDraft> relationshipTypes,
  });
}
