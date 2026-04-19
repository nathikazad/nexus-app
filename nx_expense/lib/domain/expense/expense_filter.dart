/// Optional filters for expense list (e.g. tag filters). Pure Dart.
class ExpenseFilter {
  final List<Map<String, dynamic>>? tagFilters;
  final double? minAmount;
  final double? maxAmount;

  /// Relation filters: relation type name → set of model IDs to include.
  final Map<String, Set<int>>? relationFilters;

  /// Display names for chips: relation type → model id → name (optional; falls back to `#id`).
  final Map<String, Map<int, String>>? relationFilterLabels;

  const ExpenseFilter({
    this.tagFilters,
    this.minAmount,
    this.maxAmount,
    this.relationFilters,
    this.relationFilterLabels,
  });

  bool get isEmpty =>
      (tagFilters == null || tagFilters!.isEmpty) &&
      minAmount == null &&
      maxAmount == null &&
      (relationFilters == null ||
          relationFilters!.values.every((s) => s.isEmpty));

  int get activeCount {
    var c = 0;
    if (tagFilters != null && tagFilters!.isNotEmpty) c += tagFilters!.length;
    if (minAmount != null) c++;
    if (maxAmount != null) c++;
    if (relationFilters != null) {
      for (final ids in relationFilters!.values) {
        c += ids.length;
      }
    }
    return c;
  }
}

/// Sort options for expense list.
enum ExpenseSortMode {
  dateDesc('Date (newest first)'),
  dateAsc('Date (oldest first)'),
  amountDesc('Amount (high to low)'),
  amountAsc('Amount (low to high)');

  const ExpenseSortMode(this.label);
  final String label;
}
