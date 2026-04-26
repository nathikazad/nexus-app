final class ShoppingItem {
  const ShoppingItem({
    required this.name,
    required this.amount,
    required this.initialChecked,
  });

  final String name;
  final String amount;
  final bool initialChecked;
}

final class ShoppingMealGroup {
  const ShoppingMealGroup({required this.header, required this.items});

  final String header;
  final List<ShoppingItem> items;
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
