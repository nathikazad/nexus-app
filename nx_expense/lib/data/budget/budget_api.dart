import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_db/kgql.dart';

// Shared goal DTOs and read API; mutations stay in the data layer.
export 'package:nx_db/goals.dart'
    show ExpenseGoalMonthItem, ExpenseGoalMonthResponse, fetchExpenseGoalsMonth;

Future<void> saveBudgetGoal(
  GraphQLClient client, {
  int? id,
  required String label,
  required String categoryNode,
  required num amount,
}) async {
  await setKgqlModel(
    client,
    _goalSetModelRequest(
      id: id,
      label: label,
      categoryNode: categoryNode,
      amount: amount,
    ),
    auditSourceKind: 'nx_expense_budget',
  );
}

Future<void> deleteBudgetGoal(GraphQLClient client, int id) async {
  await setKgqlModel(
    client,
    SetModelRequest(id: id, delete: true),
    auditSourceKind: 'nx_expense_budget',
  );
}

SetModelRequest _goalSetModelRequest({
  int? id,
  required String label,
  required String categoryNode,
  required num amount,
}) {
  return SetModelRequest(
    id: id,
    modelType: id == null ? 'Goal' : null,
    name: label,
    attributes: [
      SetModelAttribute(key: 'label', value: label),
      SetModelAttribute(key: 'active', value: true),
      SetModelAttribute(key: 'cadence', value: 'monthly'),
      SetModelAttribute(key: 'model_type', value: 'Expense'),
      SetModelAttribute(
        key: 'filter',
        value: {
          'tag_filters': [
            {
              'system': 'Spending Category',
              'node': categoryNode,
              'include_descendants': true,
            },
          ],
        },
      ),
      SetModelAttribute(key: 'selected_attribute', value: 'date'),
      SetModelAttribute(key: 'aggregation', value: 'sum'),
      SetModelAttribute(key: 'metric', value: 'cost'),
      SetModelAttribute(key: 'threshold_op', value: '<='),
      SetModelAttribute(key: 'threshold_value', value: amount),
      SetModelAttribute(key: 'meta', value: null),
    ],
  );
}
