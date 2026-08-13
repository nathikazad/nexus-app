import '../models/attribute.dart';
import '../models/model_type.dart';
import '../models/relation.dart';

/// Builds the `struct` map for [get_kgql_models] from a [ModelType] schema.
///
/// Walks [ModelType.attributes] and [ModelType.relations], adds optional
/// `relations` and embedded `model_type` nodes used by activity-style queries.
Map<String, dynamic> buildKgqlStructFromSchema(
  ModelType schema, {
  bool includeRelationsNode = true,
  bool includeModelTypeMeta = true,
  Iterable<String> extraTopLevel = const [
    'id',
    'name',
    'description',
    'created_at',
    'model_type_id',
  ],
}) {
  final struct = <String, dynamic>{};
  for (final k in extraTopLevel) {
    struct[k] = true;
  }

  for (final ad in schema.attributes ?? const <AttributeDefinition>[]) {
    final k = ad.key;
    if (k != null && k.isNotEmpty) {
      struct[k] = true;
    }
  }

  for (final rel in schema.relations ?? const <RelationshipType>[]) {
    final key = _relationLinkKey(rel.link);
    if (key != null) {
      struct[key] = {'id': true, 'name': true};
    }
  }

  if (includeRelationsNode) {
    struct['relations'] = {
      'relation_id': true,
      'model_id': true,
      'model_type': true,
    };
  }

  if (includeModelTypeMeta) {
    struct['model_type'] = {
      'id': true,
      'name': true,
      'type_kind': true,
    };
  }

  return struct;
}

String? _relationLinkKey(dynamic link) {
  if (link == null) return null;
  if (link is String) {
    final t = link.trim();
    return t.isEmpty ? null : t;
  }
  return link.toString();
}
