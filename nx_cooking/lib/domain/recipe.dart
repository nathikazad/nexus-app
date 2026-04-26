final class RecipeSummary {
  const RecipeSummary({
    required this.id,
    required this.title,
    required this.metaLine,
    required this.tags,
  });

  final String id;
  final String title;
  final String metaLine;
  final List<String> tags;
}
