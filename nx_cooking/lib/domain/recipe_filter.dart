/// Optional tag and ingredient filters for recipe list (KGQL `tag_filters`,
/// `relation_filters`). Pure Dart.
class RecipeFilter {
  const RecipeFilter({this.tagFilters, this.ingredientFilters});

  /// Each map: `system`, `node`, `include_descendants` (see KGQL).
  final List<Map<String, dynamic>>? tagFilters;

  /// Each map: `id` ([int]), `name` ([String]) for chip labels.
  final List<Map<String, dynamic>>? ingredientFilters;

  bool get isEmpty =>
      (tagFilters == null || tagFilters!.isEmpty) &&
      (ingredientFilters == null || ingredientFilters!.isEmpty);

  int get activeCount =>
      (tagFilters?.length ?? 0) + (ingredientFilters?.length ?? 0);
}

String tagFilterLabel(Map<String, dynamic> f) {
  final system = f['system']?.toString() ?? '';
  final node = f['node']?.toString() ?? '';
  if (system.isEmpty && node.isEmpty) return '';
  return '$system: $node';
}

String ingredientFilterLabel(Map<String, dynamic> f) {
  final name = f['name']?.toString() ?? '';
  if (name.isEmpty) return 'Ingredient';
  return 'Ingredient: $name';
}
