import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/kgql.dart';
import 'package:nx_expense/data/schema/model_type_view_mapper.dart';
import 'package:nx_expense/data/expense/expense_set_model_request.dart';
import 'package:nx_expense/domain/expense/expense_upsert.dart';

void main() {
  test('picker uses the related role count and retains both endpoints', () {
    final view = modelTypeViewFromKgql(
      ModelType.fromJson({
        'id': 1,
        'name': 'Expense',
        'relations': [
          {
            'id': 3,
            'name': 'merchant',
            'target_model_type': 'Company',
            'endpoints': {
              'expenses': {'type': 'Expense', 'count': 'many'},
              'merchant': {'type': 'Company', 'count': 'one'},
            },
          },
        ],
      }),
    );
    expect(view.relations.single.targetCount, 'one');
    expect(view.relations.single.targetEndpointName, 'merchant');
    expect(view.relations.single.endpoints.length, 2);
  });
  test('creating a replacement removes the existing link first', () {
    final payload = buildExpenseSetModelRequest(
      const ExpenseUpsert(
        id: 42,
        name: 'Lunch',
        attributes: {},
        tags: {},
        relationsByType: {'Company': []},
        relationCreatesByType: {
          'Company': {'name': 'New merchant'},
        },
        relationEdgeIdsByType: {
          'Company': {7: 100},
        },
        snapshotLinkIdsByType: {
          'Company': {7},
        },
        snapshotCreatesByType: {},
      ),
    ).toJson();
    expect(payload['relations'], [
      {'id': 100, 'delete': true},
      {
        'model_type': 'Company',
        'create': [
          {'name': 'New merchant'},
        ],
      },
    ]);
  });
}
