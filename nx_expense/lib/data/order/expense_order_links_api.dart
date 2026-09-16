import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_db/kgql.dart';
import 'package:nx_expense/domain/expense/model_names.dart';

Future<void> linkExpenseOrder(
  GraphQLClient client, {
  required int expenseId,
  required int orderId,
}) async {
  await setKgqlModel(
    client,
    SetModelRequest(
      id: expenseId,
      relations: [
        ModelRelation(modelType: kOrderModelTypeName, link: [orderId]),
      ],
    ),
  );
}

Future<void> unlinkExpenseOrder(
  GraphQLClient client, {
  required int expenseId,
  required int relationId,
}) async {
  await setKgqlModel(
    client,
    SetModelRequest(
      id: expenseId,
      relations: [ModelRelation(id: relationId, delete: true)],
    ),
  );
}
