import 'dart:convert';

import 'package:graphql_flutter/graphql_flutter.dart';

import '../../core/json/payload_unwrap.dart';
import '../documents/get_kgql_models.graphql.dart';
import '../documents/set_kgql_models.graphql.dart';
import '../models/model.dart';
import '../requests/set_model_request.dart';

/// Parse `getKgqlModels` JSON (string or list) into [Model] list.
List<Model> parseKgqlModelsResult(dynamic jsonResult) {
  if (jsonResult == null) return [];
  final jsonArray = unwrapJsonList(jsonResult);
  return jsonArray.map((e) {
    if (e is Map<String, dynamic>) {
      return Model.fromJson(e);
    }
    return null;
  }).whereType<Model>().toList();
}

/// Runs `get_kgql_models` with the given [filter] and [struct].
Future<List<Model>> fetchKgqlModels(
  GraphQLClient client, {
  required Map<String, dynamic> filter,
  required Map<String, dynamic> struct,
}) async {
  final result = await client.query(
    QueryOptions(
      document: gql(kgqlGetKgqlModelsQuery),
      variables: {
        'filter': filter,
        'struct': struct,
      },
      fetchPolicy: FetchPolicy.networkOnly,
    ),
  );

  if (result.hasException) {
    throw result.exception!;
  }

  return parseKgqlModelsResult(result.data?['getKgqlModels']);
}

/// Loads a single model by numeric id within [modelTypeName].
Future<Model?> fetchKgqlModelById(
  GraphQLClient client, {
  required String modelTypeName,
  required int id,
  required Map<String, dynamic> struct,
}) async {
  final list = await fetchKgqlModels(
    client,
    filter: {
      'model_type': modelTypeName,
      'filters': [
        {'key': 'id', 'op': '=', 'value': id.toString()},
      ],
    },
    struct: struct,
  );
  if (list.isEmpty) return null;
  return list.first;
}

/// Minimal struct for relation pickers (label + metadata).
Map<String, dynamic> get kgqlRelationPickerModelStruct => const {
      'id': true,
      'name': true,
      'description': true,
      'model_type_id': true,
      'created_at': true,
      'updated_at': true,
    };

/// Lists all models of [modelTypeName] for pickers (no date filter).
Future<List<Model>> fetchKgqlModelsForRelationPicker(
  GraphQLClient client,
  String modelTypeName,
) async {
  return fetchKgqlModels(
    client,
    filter: {'model_type': modelTypeName},
    struct: kgqlRelationPickerModelStruct,
  );
}

/// Creates or updates a model via `set_kgql_models`. Returns the model id.
Future<int> setKgqlModel(
  GraphQLClient client,
  SetModelRequest request,
) async {
  final requestJson = request.toJson();

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
    throw result.exception!;
  }

  final responseData = result.data?['setKgqlModels'] as Map<String, dynamic>?;
  if (responseData == null) {
    throw Exception('No data returned from setKgqlModels mutation');
  }

  final jsonResult = responseData['json'];
  Map<String, dynamic>? jsonData;
  if (jsonResult != null) {
    jsonData = jsonResult is String
        ? json.decode(jsonResult) as Map<String, dynamic>
        : jsonResult as Map<String, dynamic>;
  }

  if (request.delete) {
    final modelId = jsonData?['id'] as int? ?? request.id;
    if (modelId == null) {
      throw Exception('Delete: no id in response or request');
    }
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
