/// Optional tag filters for recipe list (KGQL `tag_filters`). Pure Dart.
class RecipeFilter {
  const RecipeFilter({this.tagFilters});

  /// Each map: `system`, `node`, `include_descendants` (see KGQL).
  final List<Map<String, dynamic>>? tagFilters;

  bool get isEmpty => tagFilters == null || tagFilters!.isEmpty;

  int get activeCount =>
      tagFilters == null ? 0 : tagFilters!.length;
}

String tagFilterLabel(Map<String, dynamic> f) {
  final system = f['system']?.toString() ?? '';
  final node = f['node']?.toString() ?? '';
  if (system.isEmpty && node.isEmpty) return '';
  return '$system: $node';
}
