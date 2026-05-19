class OrderProduct {
  const OrderProduct({
    required this.id,
    required this.name,
    this.unitPrice,
    this.quantity,
    this.unit,
    this.lineTotal,
    this.tax,
    this.status,
    this.deliveryDate,
    this.itemUrl,
    this.extras,
  });

  final int id;
  final String name;
  final num? unitPrice;
  final num? quantity;
  final String? unit;
  final num? lineTotal;
  final num? tax;
  final String? status;
  final String? deliveryDate;
  final String? itemUrl;
  final Map<String, dynamic>? extras;
}

class Order {
  const Order({
    required this.id,
    required this.name,
    required this.orderNumber,
    required this.orderDate,
    this.total,
    this.companyName,
    this.extras,
    this.products = const [],
  });

  final int id;
  final String name;
  final String orderNumber;
  final String orderDate;
  final num? total;
  final String? companyName;
  final Map<String, dynamic>? extras;
  final List<OrderProduct> products;

  int get itemCount {
    if (products.isEmpty) return 0;
    num count = 0;
    for (final product in products) {
      count += product.quantity ?? 1;
    }
    return count.round();
  }
}
