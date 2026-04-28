/// One row from `app.search_recipes` (PostGraphile `searchRecipes`).
sealed class RecipeSearchResult {
  const RecipeSearchResult();
}

final class RecipeSearchHit extends RecipeSearchResult {
  const RecipeSearchHit({required this.id, required this.name});

  final int id;
  final String name;
}

final class CookingItemSearchHit extends RecipeSearchResult {
  const CookingItemSearchHit({required this.id, required this.name});

  final int id;
  final String name;
}

final class TagSearchHit extends RecipeSearchResult {
  const TagSearchHit({
    required this.tagNodeId,
    required this.tagName,
    required this.tagSystemId,
    required this.tagSystemName,
  });

  final int tagNodeId;
  final String tagName;
  final int tagSystemId;
  final String tagSystemName;
}
