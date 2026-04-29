import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../../auth/auth_providers.dart';
import '../../core/client/graphql_client_provider.dart';
import '../documents/get_kgql_models.graphql.dart';
import '../models/model.dart';
import '../repositories/models_repository.dart';
import '../requests/set_model_request.dart';

int _requirePersonalDomain(Ref ref) {
  final id = ref.watch(personalDomainIdProvider);
  if (id == null) {
    throw StateError('personalDomainId required (login)');
  }
  return id;
}

final modelsProvider = FutureProvider.family<List<Model>, int>((ref, modelTypeId) async {
  final client = ref.watch(graphqlClientProvider);
  final domainId = _requirePersonalDomain(ref);

  final queryOptions = QueryOptions(
    document: gql(kgqlGetKgqlModelsQuery),
    variables: {
      'filter': {
        'model_type': modelTypeId,
      },
      'struct': {
        'id': true,
        'name': true,
        'description': true,
        'model_type_id': true,
        'created_at': true,
        'updated_at': true,
      },
      'domainId': domainId,
    },
    fetchPolicy: FetchPolicy.networkOnly,
  );

  final result = await client.query(queryOptions);

  if (result.hasException) {
    throw result.exception!;
  }

  final models = parseKgqlModelsResult(result.data?['getKgqlModels']);

  return models.where((model) => model.modelTypeId == modelTypeId).toList();
});

final modelProvider = FutureProvider.family<Model?, int>((ref, modelId) async {
  final client = ref.watch(graphqlClientProvider);
  final domainId = _requirePersonalDomain(ref);

  final queryOptions = QueryOptions(
    document: gql(kgqlGetKgqlModelsQuery),
    variables: {
      'filter': {
        'filters': [
          {'key': 'id', 'op': '=', 'value': modelId.toString()},
        ],
      },
      'struct': {
        'id': true,
        'name': true,
        'description': true,
        'model_type_id': true,
        'created_at': true,
        'updated_at': true,
        'attributes': {
          'id': true,
          'key': true,
          'value': true,
          'value_type': true,
        },
        'relations': {
          'relation_id': true,
          'model_id': true,
          'model_type': true,
          'name': true,
          'description': true,
        },
      },
      'domainId': domainId,
    },
    fetchPolicy: FetchPolicy.networkOnly,
  );

  final result = await client.query(queryOptions);

  if (result.hasException) {
    throw result.exception!;
  }

  final list = parseKgqlModelsResult(result.data?['getKgqlModels']);
  if (list.isEmpty) {
    return null;
  }

  return list.first;
});

/// Creates or updates a model using [setKgqlModel].
/// When [domainId] is null, uses the logged-in user's [personalDomainIdProvider].
Future<int> createModel(
  ProviderContainer container,
  SetModelRequest request, {
  int? domainId,
}) async {
  final client = container.read(graphqlClientProvider);
  final resolved = domainId ?? container.read(personalDomainIdProvider);
  if (resolved == null) {
    throw StateError('domainId or logged-in personalDomainId required');
  }
  return setKgqlModel(client, request, domainId: resolved);
}

/// Updates an existing model using [setKgqlModel].
Future<int> updateModel(
  ProviderContainer container,
  SetModelRequest request, {
  int? domainId,
}) async {
  if (request.id == null) {
    throw Exception('updateModel requires an id field in the request');
  }

  return createModel(container, request, domainId: domainId);
}
