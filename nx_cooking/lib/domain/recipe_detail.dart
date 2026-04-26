final class IngredientLine {
  const IngredientLine({
    required this.name,
    required this.amount,
    required this.initialChecked,
  });

  final String name;
  final String amount;
  final bool initialChecked;
}

final class RecipeDetail {
  const RecipeDetail({
    required this.id,
    required this.title,
    required this.headerLine,
    required this.statusChip,
    required this.ingredients,
    required this.instructionLines,
  });

  final String id;
  final String title;
  final String headerLine;
  final String statusChip;
  final List<IngredientLine> ingredients;
  final List<String> instructionLines;
}
