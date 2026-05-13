import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/client/graphql_client_provider.dart';
import '../models/model_type.dart';
import '../repositories/model_types_repository.dart';

/// [getKgqlModelType] for [name].
final kgqlModelTypeByNameProvider =
    FutureProvider.family<ModelType, String>((ref, name) async {
  return fetchKgqlModelTypeByName(
    ref.watch(graphqlClientProvider),
    name,
  );
});
