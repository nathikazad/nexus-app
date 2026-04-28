final class RecipeSummary {
  const RecipeSummary({
    required this.id,
    required this.title,
    required this.metaLine,
    this.ingredientCount = 0,
    this.prepTimeMinutes,
  });

  /// Model id as string for routes (`/recipe/:id`).
  final String id;
  final String title;
  final String metaLine;
  final int ingredientCount;
  final int? prepTimeMinutes;
}
