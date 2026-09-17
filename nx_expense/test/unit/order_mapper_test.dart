import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/kgql.dart';
import 'package:nx_expense/data/order/kgql_order_repository.dart';
import 'package:nx_expense/domain/order/order.dart';

void main() {
  test(
    'Order retains saved source links, product assets, and quantity totals',
    () {
      final order = orderFromModel(
        Model.fromJson({
          'id': 1,
          'name': 'Order',
          'model_type_id': 2,
          'order_number': '111-123',
          'order_date': '2026-09-15',
          'extras': {
            'order_details_url':
                'https://www.amazon.com/your-orders/order-details?orderID=111-123',
          },
          'Product': [
            {
              'id': 8,
              'name': 'Adapters',
              'image_url': '/images/adapters.jpg',
              'item_url': 'https://www.amazon.com/dp/TEST',
            },
          ],
          'relations': [
            {
              'model_id': 8,
              'model_type': 'Product',
              'relation_attributes': [
                {'key': 'unit_price', 'value': '12.50', 'value_type': 'number'},
                {'key': 'quantity', 'value': 2, 'value_type': 'number'},
                {
                  'key': 'extras',
                  'value': '{"tax":1.25}',
                  'value_type': 'json',
                },
              ],
            },
          ],
        }),
      );
      expect(order.sourceUrl, contains('orderID=111-123'));
      expect(order.products.single.imageUrl, '/images/adapters.jpg');
      expect(order.products.single.itemUrl, 'https://www.amazon.com/dp/TEST');
      expect(order.products.single.effectiveLineTotal, 25);
      expect(order.products.single.tax, 1.25);
      expect(order.itemCount, 2);
    },
  );
  test('explicit line totals win; unknown prices remain unknown', () {
    expect(
      const OrderProduct(
        id: 1,
        name: 'X',
        unitPrice: 10,
        quantity: 3,
        lineTotal: 28,
      ).effectiveLineTotal,
      28,
    );
    expect(
      const OrderProduct(id: 1, name: 'X', quantity: 3).effectiveLineTotal,
      isNull,
    );
  });
  test('unsafe source URLs are rejected, with saved source fallback', () {
    const order = Order(
      id: 1,
      name: 'X',
      orderNumber: 'X',
      orderDate: '',
      extras: {
        'order_details_url': 'javascript:alert(1)',
        'source_url': 'https://amazon.com/order',
      },
    );
    expect(order.sourceUrl, 'https://amazon.com/order');
  });
}
