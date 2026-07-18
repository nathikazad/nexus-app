class ExpenseProductLine {
  const ExpenseProductLine({
    required this.id,
    required this.name,
    this.brand,
    this.imageUrl,
    this.itemUrl,
    this.price,
    this.quantity,
    this.unit,
  });

  final int id;
  final String name;
  final String? brand;
  final String? imageUrl;
  final String? itemUrl;
  final num? price;
  final num? quantity;
  final String? unit;

  num? get lineTotal {
    if (price == null) return null;
    return price! * (quantity ?? 1);
  }
}
