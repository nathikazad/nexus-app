final class ShoppingItem {
  const ShoppingItem({
    required this.taskId,
    required this.taskRelationId,
    required this.itemId,
    required this.name,
    required this.amount,
    required this.initialChecked,
    this.groupName,
    this.preparation,
  });

  final int taskId;
  final int taskRelationId;
  final int itemId;
  final String name;
  final String amount;
  final bool initialChecked;

  /// `has_ingredient.group_name` when present.
  final String? groupName;

  /// `has_ingredient.preparation` when present.
  final String? preparation;
}

final class ShoppingMealGroup {
  const ShoppingMealGroup({
    required this.header,
    required this.items,
    required this.taskId,
    required this.taskRelationId,
  });

  final String header;
  final List<ShoppingItem> items;
  final int taskId;
  final int taskRelationId;
}

final class ShoppingListSnapshot {
  const ShoppingListSnapshot({
    required this.purchasedCount,
    required this.totalCount,
    required this.groups,
  });

  final int purchasedCount;
  final int totalCount;
  final List<ShoppingMealGroup> groups;
}
