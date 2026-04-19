import 'dart:convert';

import 'package:flutter/foundation.dart';
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
  final modelType = filter['model_type'];
  final filters = filter['filters'];
  debugPrint(
    '[nx_db fetchKgqlModels] START model_type=$modelType '
    'filters=$filters structTopLevelKeys=${struct.keys.toList()}',
  );

  final sw = Stopwatch()..start();
  QueryResult result;
  try {
    result = await client.query(
      QueryOptions(
        document: gql(kgqlGetKgqlModelsQuery),
        variables: {
          'filter': filter,
          'struct': struct,
        },
        fetchPolicy: FetchPolicy.networkOnly,
      ),
    );
  } catch (e, st) {
    sw.stop();
    debugPrint(
      '[nx_db fetchKgqlModels] client.query threw after ${sw.elapsedMilliseconds}ms: $e',
    );
    debugPrint('[nx_db fetchKgqlModels] $st');
    rethrow;
  }
  sw.stop();

  debugPrint(
    '[nx_db fetchKgqlModels] client.query finished in ${sw.elapsedMilliseconds}ms '
    'hasException=${result.hasException}',
  );

  if (result.hasException) {
    debugPrint('[nx_db fetchKgqlModels] GraphQL exception: ${result.exception}');
    throw result.exception!;
  }

  final parsed = parseKgqlModelsResult(result.data?['getKgqlModels']);
  debugPrint('[nx_db fetchKgqlModels] parsed ${parsed.length} Model(s)');
  return parsed;
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
  debugPrint(
    '[setKgqlModel] ${request.delete ? "DELETE" : "save"} '
    'id=${request.id} modelType=${request.modelType}',
  );

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
    debugPrint('[setKgqlModel] GraphQL exception: ${result.exception}');
    throw result.exception!;
  }

  final responseData = result.data?['setKgqlModels'] as Map<String, dynamic>?;
  if (responseData == null) {
    debugPrint('[setKgqlModel] missing setKgqlModels in result.data=${result.data}');
    throw Exception('No data returned from setKgqlModels mutation');
  }

  final jsonResult = responseData['json'];
  Map<String, dynamic>? jsonData;
  if (jsonResult != null) {
    jsonData = jsonResult is String
        ? json.decode(jsonResult) as Map<String, dynamic>
        : jsonResult as Map<String, dynamic>;
  }
  debugPrint('[setKgqlModel] response json field: $jsonData');

  if (request.delete) {
    final modelId = jsonData?['id'] as int? ?? request.id;
    if (modelId == null) {
      throw Exception('Delete: no id in response or request');
    }
    debugPrint('[setKgqlModel] DELETE ok → id=$modelId');
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
