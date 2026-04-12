import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db.dart';
import '../models/Model.dart';
import '../models/ModelType.dart';
import 'kgql_fetch.dart';

/// Cached [ModelType] by **name** (e.g. `"Expense"`, `"Company"`) using [kgqlFullModelTypeStruct].
final modelTypeByNameProvider =
    FutureProvider.family<ModelType, String>((ref, modelTypeName) async {
  final client = ref.watch(graphqlClientProvider);
  return fetchKgqlModelTypeByName(client, modelTypeName);
});

/// All models of a type (relation pickers, simple lists).
final relatedModelsByTypeNameProvider =
    FutureProvider.family<List<Model>, String>((ref, modelTypeName) async {
  final client = ref.watch(graphqlClientProvider);
  return fetchKgqlModelsForRelationPicker(client, modelTypeName);
});
