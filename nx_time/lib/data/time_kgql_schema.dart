import 'package:nx_db/nx_db.dart';

/// Abstract Action type — `get_kgql_models` with `model_type: Action` returns rows for
/// Action and all concrete descendants (Sleep, Meet, Goto, …).
const String kActionModelTypeName = 'Action';

/// Builds the `struct` for listing/querying activity rows under [Action] from [ModelType].
///
/// Includes all attribute keys from the schema, nested `{id, name}` for each related
/// model type, a generic `relations` node for edge IDs, and **embedded model type metadata**
/// via `struct.model_type` (see `get_kgql_models` human docs — distinct CTE, one lookup per row).
Map<String, dynamic> buildActionActivityStruct(ModelType schema) {
  final struct = <String, dynamic>{
    'id': true,
    'name': true,
    'description': true,
    'created_at': true,
    'model_type_id': true,
  };

  for (final ad in schema.attributes ?? const <AttributeDefinition>[]) {
    final k = ad.key;
    if (k != null && k.isNotEmpty) {
      struct[k] = true;
    }
  }

  for (final rel in schema.relations ?? const <RelationshipType>[]) {
    final link = rel.link;
    if (link != null && link.isNotEmpty) {
      struct[link] = {'id': true, 'name': true};
    }
  }

  struct['relations'] = {
    'relation_id': true,
    'model_id': true,
    'model_type': true,
  };

  struct['model_type'] = {
    'id': true,
    'name': true,
    'type_kind': true,
  };

  return struct;
}
