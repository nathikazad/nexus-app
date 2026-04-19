import 'package:nx_db/nx_db.dart' show ModelType, buildKgqlStructFromSchema;

/// Builds the `struct` map for [get_kgql_models] from a [ModelType] schema
/// (same as [buildKgqlStructFromSchema]; kept for a stable app-local import).
Map<String, dynamic> navigatorKgqlStructForSchema(
  ModelType schema, {
  bool includeRelationsNode = true,
  bool includeModelTypeMeta = true,
}) {
  return buildKgqlStructFromSchema(
    schema,
    includeRelationsNode: includeRelationsNode,
    includeModelTypeMeta: includeModelTypeMeta,
  );
}
