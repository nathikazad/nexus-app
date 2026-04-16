import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../db.dart';
import '../models/Model.dart';
import '../models/requests/SetModelRequest.dart';
import 'kgql_fetch.dart';

const String setKgqlModelsMutation = '''
mutation SetKgqlModels(\$input: SetKgqlModelsInput!) {
  setKgqlModels(input: \$input) {
    json
  }
}
''';

final modelsProvider = FutureProvider.family<List<Model>, int>((ref, modelTypeId) async {
  final client = ref.watch(graphqlClientProvider);


  final queryOptions = QueryOptions(
    document: gql(kgqlGetKgqlModelsQuery),
    variables: {
      'filter': {
        'model_type': modelTypeId, // Use model type name, not ID
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

  // Filter by modelTypeId as a safety check (should already be filtered by model_type name)
  return models.where((model) => model.modelTypeId == modelTypeId).toList();
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

/// Creates a new model using set_kgql_models.
///
/// Takes a [SetModelRequest] that matches the structure expected by
/// set_kgql_models function. See: servers/pgdb/docs/human-reference/set_kgql_models.md
///
/// Returns the ID of the created model.
Future<int> createModel(
  ProviderContainer container,
  SetModelRequest request,
) async {
  final client = container.read(graphqlClientProvider);

  // Convert request to JSON
  final requestJson = request.toJson();
  debugPrint(
    '[createModel] ${request.delete ? "DELETE" : "save"} '
    'id=${request.id} modelType=${request.modelType}',
  );

  // Call set_kgql_models mutation
  // PostGraphile wraps JSON functions in input/output structure
  final result = await client.mutate(
    MutationOptions(
      document: gql(setKgqlModelsMutation),
      variables: {
        'input': {
          'data': requestJson,
        },
      },
    ),
  );

  if (result.hasException) {
    debugPrint('[createModel] GraphQL exception: ${result.exception}');
    throw result.exception!;
  }

  // Extract the created/updated model ID
  // PostGraphile returns JSON result in a 'json' field
  final responseData = result.data?['setKgqlModels'] as Map<String, dynamic>?;
  if (responseData == null) {
    debugPrint('[createModel] missing setKgqlModels in result.data=${result.data}');
    throw Exception('No data returned from setKgqlModels mutation');
  }

  // The JSON result is in the 'json' field (may be null for some delete responses)
  final jsonResult = responseData['json'];
  Map<String, dynamic>? jsonData;
  if (jsonResult != null) {
    jsonData = jsonResult is String
        ? json.decode(jsonResult) as Map<String, dynamic>
        : jsonResult as Map<String, dynamic>;
  }
  debugPrint('[createModel] response json field: $jsonData');

  // Deletes often omit `id` in the JSON body; fall back to request.id.
  if (request.delete) {
    final modelId = jsonData?['id'] as int? ?? request.id;
    if (modelId == null) {
      throw Exception('Delete: no id in response or request');
    }
    debugPrint('[createModel] DELETE ok → id=$modelId');
    return modelId;
  }

  if (jsonData == null) {
    throw Exception('No JSON in setKgqlModels response');
  }

  final modelId = jsonData['id'] as int?;
  if (modelId == null) {
    throw Exception('No ID returned from setKgqlModels mutation');
  }

  return modelId;
}

/// Updates an existing model using set_kgql_models.
///
/// Takes a [SetModelRequest] with an `id` field that matches the structure expected by
/// set_kgql_models function. See: servers/pgdb/docs/human-reference/set_kgql_models.md
///
/// Returns the ID of the updated model.
Future<int> updateModel(
  ProviderContainer container,
  SetModelRequest request,
) async {
  if (request.id == null) {
    throw Exception('updateModel requires an id field in the request');
  }

  return createModel(container, request);
}
