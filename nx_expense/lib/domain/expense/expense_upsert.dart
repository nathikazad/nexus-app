/// Payload for create/update expense from the form (pure Dart).
class ExpenseUpsert {
  const ExpenseUpsert({
    this.id,
    required this.name,
    this.description,
    required this.attributes,
    required this.tags,
    required this.relationsByType,
    required this.relationCreatesByType,
    required this.relationEdgeIdsByType,
    required this.snapshotLinkIdsByType,
    required this.snapshotCreatesByType,
  });

  final int? id;
  final String name;
  final String? description;

  /// Coerced attribute key → value (non-empty only).
  final Map<String, dynamic> attributes;

  /// Tag system name → selected node names.
  final Map<String, List<String>> tags;

  final Map<String, List<int>> relationsByType;
  final Map<String, Map<String, dynamic>?> relationCreatesByType;
  final Map<String, Map<int, int>> relationEdgeIdsByType;
  final Map<String, Set<int>> snapshotLinkIdsByType;
  final Map<String, Map<String, dynamic>?> snapshotCreatesByType;
}
