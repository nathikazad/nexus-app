import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/kgql.dart';
import 'package:nx_db/riverpod.dart';

import 'package:nx_expense/domain/expense/model_names.dart';

final expenseModelTypeKgqlProvider =
    FutureProvider<ModelType>((ref) async {
  return ref.watch(modelTypeByNameProvider(kExpenseModelTypeName).future);
});
