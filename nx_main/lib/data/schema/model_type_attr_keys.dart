/// Attribute / field keys used when building KGQL model-type payloads in the
/// schema navigator. Centralize to avoid string drift vs `nx_db` documents.
abstract final class ModelTypeAttrKeys {
  ModelTypeAttrKeys._();

  static const name = 'name';
  static const description = 'description';
  static const typeKind = 'type_kind';
  static const parentId = 'parent_id';
}
