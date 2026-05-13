import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/client/graphql_client_provider.dart';
import '../models/model.dart';
import '../repositories/models_repository.dart';

/// All models of a type for relation pickers.
final relatedModelsByTypeNameProvider =
    FutureProvider.family<List<Model>, String>((ref, modelTypeName) async {
  final client = ref.watch(graphqlClientProvider);
  return fetchKgqlModelsForRelationPicker(
    client,
    modelTypeName,
  );
});
