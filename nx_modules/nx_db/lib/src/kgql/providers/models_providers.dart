import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../../core/client/graphql_client_provider.dart';
import '../documents/get_kgql_models.graphql.dart';
import '../models/model.dart';
import '../models/model_list_query.dart';
import '../repositories/models_repository.dart';
import '../requests/set_model_request.dart';

final modelsProvider =
    FutureProvider.family<List<Model>, int>((ref, modelTypeId) async {
  final client = ref.watch(graphqlClientProvider);

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

final modelListProvider =
    FutureProvider.family<List<Model>, ModelListQuery>((ref, query) async {
  final client = ref.watch(graphqlClientProvider);

  final rows = await fetchKgqlModels(
    client,
    filter: query.toKgqlFilter(),
    struct: const {
      'id': true,
      'name': true,
      'description': true,
      'model_type_id': true,
      'created_at': true,
      'updated_at': true,
      'model_type': {
        'id': true,
        'name': true,
        'description': true,
      },
    },
  );

  return rows;
});

final modelProvider = FutureProvider.family<Model?, int>((ref, modelId) async {
  final client = ref.watch(graphqlClientProvider);

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
          'relation': true,
          'relation_attributes': {
            'key': true,
            'value': true,
          },
        },
        'tags': true,
        'model_type': {
          'id': true,
          'name': true,
          'description': true,
        },
      },
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
Future<int> createModel(
  ProviderContainer container,
  SetModelRequest request,
) async {
  final client = container.read(graphqlClientProvider);
  return setKgqlModel(client, request);
}

/// Updates an existing model using [setKgqlModel].
Future<int> updateModel(
  ProviderContainer container,
  SetModelRequest request,
) async {
  if (request.id == null) {
    throw Exception('updateModel requires an id field in the request');
  }

  return createModel(container, request);
}
