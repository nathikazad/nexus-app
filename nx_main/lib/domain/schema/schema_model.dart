import 'schema_model_attribute.dart';
import 'schema_model_type.dart';
import 'schema_relation.dart';

/// KGQL model instance for schema navigator UI.
class SchemaModel {
  final int id;
  final String name;
  final String? description;
  final int modelTypeId;
  final String? createdAt;
  final String? updatedAt;
  final Map<String, dynamic>? attributes;
  final List<SchemaModelAttribute>? attributesList;
  final Map<String, List<SchemaModel>>? relations;
  final List<SchemaRelation>? relationsList;
  final Map<String, List<String>>? tags;
  final SchemaModelType? modelType;

  const SchemaModel({
    required this.id,
    required this.name,
    this.description,
    required this.modelTypeId,
    this.createdAt,
    this.updatedAt,
    this.attributes,
    this.attributesList,
    this.relations,
    this.relationsList,
    this.tags,
    this.modelType,
  });

  Map<String, List<SchemaRelation>> get relationsByModelType {
    if (relationsList == null || relationsList!.isEmpty) {
      return {};
    }
    final grouped = <String, List<SchemaRelation>>{};
    for (final relation in relationsList!) {
      grouped.putIfAbsent(relation.modelType, () => []).add(relation);
    }
    return grouped;
  }
}
