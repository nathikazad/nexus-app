final class IngredientLine {
  const IngredientLine({
    required this.name,
    required this.amount,
    this.initialChecked = false,
    this.relationId,
    this.itemId,
  });

  final String name;
  final String amount;
  final bool initialChecked;

  /// Present when loaded from KGQL (for edit round-trip).
  final int? relationId;
  final int? itemId;
}

/// Full recipe view (read-only detail + mapping from KGQL).
final class RecipeDetail {
  const RecipeDetail({
    required this.id,
    required this.title,
    this.tags = const [],
    this.prepTimeMinutes,
    this.servings,
    this.notes,
    this.lastCookedLabel,
    this.headerLine,
    this.statusChip,
    required this.ingredients,
    required this.instructionLines,
  });

  final int id;
  final String title;
  final List<String> tags;
  final int? prepTimeMinutes;
  final int? servings;
  final String? notes;
  final String? lastCookedLabel;
  final String? headerLine;
  final String? statusChip;
  final List<IngredientLine> ingredients;
  final List<String> instructionLines;
}

/// One editable ingredient row in create / edit.
final class RecipeIngredientFormLine {
  RecipeIngredientFormLine({
    this.relationId,
    this.itemId,
    required this.name,
    required this.quantityText,
    required this.unit,
  });

  int? relationId;
  int? itemId;
  String name;
  String quantityText;
  String unit;
}

/// Form state for create and update.
final class RecipeFormData {
  RecipeFormData({
    required this.name,
    required this.tags,
    required this.prepTimeMinutesText,
    required this.servingsText,
    required this.notes,
    required this.ingredients,
    required this.instructionSteps,
  });

  String name;
  List<String> tags;
  String prepTimeMinutesText;
  String servingsText;
  String notes;
  List<RecipeIngredientFormLine> ingredients;
  List<String> instructionSteps;

  factory RecipeFormData.empty() {
    return RecipeFormData(
      name: '',
      tags: [],
      prepTimeMinutesText: '',
      servingsText: '',
      notes: '',
      ingredients: [
        RecipeIngredientFormLine(name: '', quantityText: '', unit: ''),
      ],
      instructionSteps: [''],
    );
  }

  factory RecipeFormData.fromDetail(RecipeDetail d) {
    return RecipeFormData(
      name: d.title,
      tags: List<String>.from(d.tags),
      prepTimeMinutesText: d.prepTimeMinutes?.toString() ?? '',
      servingsText: d.servings?.toString() ?? '',
      notes: d.notes ?? '',
      ingredients: d.ingredients.map((e) {
        final parts = _splitAmount(e.amount);
        return RecipeIngredientFormLine(
          relationId: e.relationId,
          itemId: e.itemId,
          name: e.name,
          quantityText: parts.$1,
          unit: parts.$2,
        );
      }).toList(),
      instructionSteps: d.instructionLines.isEmpty
          ? ['']
          : List<String>.from(d.instructionLines),
    );
  }
}

/// Best-effort split of a single display string into quantity + unit.
(String, String) _splitAmount(String amount) {
  final t = amount.trim();
  if (t.isEmpty) return ('', '');
  final space = RegExp(r'\s+');
  final parts = t.split(space);
  if (parts.length == 1) return (parts[0], '');
  return (parts.first, parts.sublist(1).join(' '));
}
