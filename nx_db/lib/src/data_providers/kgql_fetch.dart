import 'dart:convert';

import 'package:graphql_flutter/graphql_flutter.dart';

import '../models/Model.dart';
import '../models/ModelType.dart';

/// Shared GraphQL document for `get_kgql_models` (alias name may vary per query).
const String kgqlGetKgqlModelsQuery = '''
query GetKgqlModels(\$filter: JSON!, \$struct: JSON!) {
  getKgqlModels(filter: \$filter, struct: \$struct)
}
''';

/// Shared GraphQL document for `get_kgql_model_type`.
const String kgqlGetKgqlModelTypeQuery = '''
query GetKgqlModelType(\$input: JSON!) {
  getKgqlModelType(input: \$input)
}
''';

/// Default struct for loading a full [ModelType] by name (Expense / Transfer apps).
Map<String, dynamic> get kgqlFullModelTypeStruct => const {
      'id': true,
      'name': true,
      'type_kind': true,
      'description': true,
      'parent': true,
      'children': true,
      'traits': true,
      'attributes': true,
      'relations': true,
      'tag_systems': true,
    };

/// Parse `getKgqlModels` JSON (string or list) into [Model] list.
List<Model> parseKgqlModelsResult(dynamic jsonResult) {
  if (jsonResult == null) return [];
  final jsonArray = jsonResult is String
      ? json.decode(jsonResult) as List<dynamic>
      : jsonResult as List<dynamic>;
  return jsonArray.map((e) {
    if (e is Map<String, dynamic>) {
      return Model.fromJson(e);
    }
    return null;
  }).whereType<Model>().toList();
}

/// Loads a single [ModelType] by name (e.g. `"Expense"`).
///
/// [struct] defaults to [kgqlFullModelTypeStruct].
Future<ModelType> fetchKgqlModelTypeByName(
  GraphQLClient client,
  String modelTypeName, {
  Map<String, dynamic>? struct,
}) async {
  final result = await client.query(
    QueryOptions(
      document: gql(kgqlGetKgqlModelTypeQuery),
      variables: {
        'input': {
          'model_types': [modelTypeName],
          'struct': struct ?? kgqlFullModelTypeStruct,
        },
      },
      fetchPolicy: FetchPolicy.networkOnly,
    ),
  );

  if (result.hasException) {
    throw result.exception!;
  }

  final raw = result.data?['getKgqlModelType'];
  if (raw == null) {
    throw StateError('getKgqlModelType returned null');
  }

  final jsonArray = raw is String
      ? json.decode(raw) as List<dynamic>
      : raw as List<dynamic>;

  if (jsonArray.isEmpty) {
    throw StateError('Model type "$modelTypeName" not found');
  }

  return ModelType.fromJson(
    jsonArray.first as Map<String, dynamic>,
    recursive: true,
  );
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
