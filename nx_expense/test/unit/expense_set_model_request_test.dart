import 'package:flutter_test/flutter_test.dart';
import 'package:nx_expense/data/expense/expense_set_model_request.dart';
import 'package:nx_expense/domain/expense/expense_upsert.dart';

void main() {
  test('empty tag selection is sent as an explicit clear', () {
    final request = buildExpenseSetModelRequest(
      const ExpenseUpsert(
        id: 4248,
        name: 'Dinner',
        attributes: {},
        tags: {
          'Trips': [],
          'Category': ['Restaurants'],
        },
        relationsByType: {},
        relationCreatesByType: {},
        relationEdgeIdsByType: {},
        snapshotLinkIdsByType: {},
        snapshotCreatesByType: {},
      ),
    );

    final json = request.toJson();

    expect(json['tags'], [
      {'system': 'Trips', 'nodes': <String>[], 'clear': true},
      {
        'system': 'Category',
        'nodes': ['Restaurants'],
      },
    ]);
  });
}
