final class RecipeSummary {
  const RecipeSummary({
    required this.id,
    required this.title,
    required this.metaLine,
    required this.tags,
    this.ingredientCount = 0,
    this.prepTimeMinutes,
  });

  /// Model id as string for routes (`/recipe/:id`).
  final String id;
  final String title;
  final String metaLine;
  final List<String> tags;
  final int ingredientCount;
  final int? prepTimeMinutes;
}
