import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/client/graphql_client_provider.dart';
import '../models/model.dart';
import '../models/model_type.dart';
import '../repositories/model_types_repository.dart';
import '../repositories/models_repository.dart';

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
