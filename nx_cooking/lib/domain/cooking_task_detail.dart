/// Planned cooking task: recipe + ingredients, instructions, optional task [notes].
final class CookingTaskDetail {
  const CookingTaskDetail({
    required this.taskId,
    required this.taskRelationId,
    required this.recipeId,
    required this.recipeName,
    required this.plannedDate,
    required this.status,
    required this.tags,
    this.prepTimeMinutes,
    this.servings,
    this.notes,
    required this.ingredients,
    required this.instructionLines,
  });

  final int taskId;
  final int taskRelationId;
  final int recipeId;
  final String recipeName;
  final DateTime plannedDate;
  final String status;
  final List<String> tags;
  final int? prepTimeMinutes;
  final int? servings;
  final String? notes;
  final List<TaskIngredient> ingredients;
  final List<String> instructionLines;
}

final class TaskIngredient {
  const TaskIngredient({
    required this.itemId,
    required this.name,
    required this.amount,
    required this.checked,
    this.groupName,
    this.preparation,
  });

  final int itemId;
  final String name;
  final String amount;
  final bool checked;
  final String? groupName;
  final String? preparation;
}
