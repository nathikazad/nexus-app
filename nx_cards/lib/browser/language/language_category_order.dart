List<String> orderedLanguageCategories(Iterable<String?> values) {
  final categories = <String>{
    for (final value in values)
      if (value?.trim() case final category? when category.isNotEmpty) category,
  }.toList(growable: false);

  categories.sort((left, right) {
    final priorityComparison = _priority(left).compareTo(_priority(right));
    if (priorityComparison != 0) return priorityComparison;
    return left.toLowerCase().compareTo(right.toLowerCase());
  });
  return categories;
}

int _priority(String category) => switch (category.toLowerCase()) {
  'script' => 0,
  'word' => 1,
  'phrase' => 2,
  'noun' => 3,
  'verb' => 4,
  _ => 5,
};
