import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/client/graphql_client_provider.dart';
import '../models/model.dart';
import '../repositories/models_repository.dart';

/// Record key for model-type name + domain id (relation pickers, tests).
typedef RelatedModelsPickerArgs = ({String modelTypeName, int domainId});

/// All models of a type for relation pickers (caller supplies [domainId]).
final relatedModelsByTypeNameProvider =
    FutureProvider.family<List<Model>, RelatedModelsPickerArgs>((ref, args) async {
  final client = ref.watch(graphqlClientProvider);
  return fetchKgqlModelsForRelationPicker(
    client,
    args.modelTypeName,
    domainId: args.domainId,
  );
});
