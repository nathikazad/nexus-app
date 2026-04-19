/// Tag system metadata shown on model type detail (no tree nodes).
class SchemaTagSystemSummary {
  final int id;
  final String name;
  final bool isHierarchical;
  final String selectionMode;

  const SchemaTagSystemSummary({
    required this.id,
    required this.name,
    required this.isHierarchical,
    required this.selectionMode,
  });
}
