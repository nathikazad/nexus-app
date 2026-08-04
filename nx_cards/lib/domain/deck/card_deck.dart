class CardDeck {
  const CardDeck({
    required this.id,
    required this.name,
    required this.description,
    required this.language,
    required this.archived,
    this.updatedAt,
  });

  final int id;
  final String name;
  final String description;
  final String? language;
  final bool archived;

  /// Kept in the domain model so a future offline store can resolve remote
  /// changes without exposing KGQL rows to the UI.
  final DateTime? updatedAt;
}
