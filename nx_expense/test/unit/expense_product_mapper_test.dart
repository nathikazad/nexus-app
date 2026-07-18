import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/kgql.dart';
import 'package:nx_expense/data/expense/expense_mapper.dart';

void main() {
  test(
    'maps Product attributes and Expense relation attributes into a line',
    () {
      final model = Model.fromJson({
        'id': 2755,
        'name': 'Sink Plunger and Soldering Station',
        'model_type_id': 1,
        'cost': -24.96,
        'Product': [
          {
            'id': 91,
            'name': "Luigi's Mini Sink Plunger",
            'model_type_id': 2,
            'brand': "Luigi's",
            'image_url': '/images/plunger.jpg',
            'item_url': 'https://example.com/plunger',
          },
        ],
        'relations': [
          {
            'relation_id': 501,
            'model_id': 91,
            'model_type': 'Product',
            'relation_attributes': [
              {'key': 'price', 'value': '9.99', 'value_type': 'number'},
              {'key': 'quantity', 'value': 2, 'value_type': 'number'},
              {'key': 'unit', 'value': 'item', 'value_type': 'string'},
            ],
          },
        ],
      });

      final expense = expenseFromModel(model);

      expect(expense.products, hasLength(1));
      final product = expense.products.single;
      expect(product.id, 91);
      expect(product.brand, "Luigi's");
      expect(product.imageUrl, '/images/plunger.jpg');
      expect(product.itemUrl, 'https://example.com/plunger');
      expect(product.price, 9.99);
      expect(product.quantity, 2);
      expect(product.unit, 'item');
      expect(product.lineTotal, 19.98);
      expect(
        expense.relationsList!.single.relationAttributes!['price'],
        '9.99',
      );
    },
  );
}
