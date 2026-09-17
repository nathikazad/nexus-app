import 'package:flutter_test/flutter_test.dart';
import 'package:nx_expense/data/sync/expense_model_cache.dart';
import 'package:nx_expense/data/expense/expense_mapper.dart';

void main() {
  final row = <String, dynamic>{
    'id': 1,
    'name': 'Order',
    'model_type_id': 2,
    'attributes': {'date': '2026-09-16T12:00:00', 'total': 30},
    'tags': {
      'Category': ['Groceries'],
    },
    'relations': [
      {
        'relation_id': 7,
        'model_id': 2,
        'model_type': 'Product',
        'name': 'Apples',
        'related_attributes': {'image_url': '/images/apples.jpg'},
        'relation_attributes': [
          {'key': 'price', 'value': 15},
          {'key': 'quantity', 'value': 2},
        ],
      },
    ],
  };
  test(
    'snapshot preserves product image and line-item relation attributes',
    () {
      final model = expenseSyncModel(row);
      expect(
        model.relations!['Product']!.single.attributes!['image_url'],
        '/images/apples.jpg',
      );
      expect(model.relationsList!.single.relationAttributes, {
        'price': 15,
        'quantity': 2,
      });
      expect(expenseFromModel(model).name, 'Order');
    },
  );
  test('offline lists apply inclusive dates, relation and descendant tags', () {
    final references = <String, dynamic>{
      'tag_systems': [
        {
          'name': 'Category',
          'nodes': [
            {'id': 1, 'name': 'Shopping', 'parent_id': null},
            {'id': 2, 'name': 'Groceries', 'parent_id': 1},
          ],
        },
      ],
    };
    final filter = <String, dynamic>{
      'filters': [
        {'key': 'date', 'op': '>=', 'value': '2026-09-16'},
        {'key': 'date', 'op': '<=', 'value': '2026-09-16'},
      ],
      'relation_filters': [
        {
          'model_type': 'Product',
          'model_ids': [2],
        },
      ],
      'tag_filters': [
        {'system': 'Category', 'node': 'Shopping', 'include_descendants': true},
      ],
    };
    expect(matchesExpenseSyncFilter(row, filter, references), true);
    expect(
      matchesExpenseSyncFilter(
        {
          ...row,
          'attributes': {'date': '2026-09-17'},
        },
        filter,
        references,
      ),
      false,
    );
    expect(
      matchesExpenseSyncFilter({...row, 'relations': []}, filter, references),
      false,
    );
    expect(
      matchesExpenseSyncFilter({...row, 'tags': {}}, filter, references),
      false,
    );
  });
}
