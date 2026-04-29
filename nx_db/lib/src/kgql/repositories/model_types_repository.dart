import 'dart:convert';

import 'package:graphql_flutter/graphql_flutter.dart';

import '../documents/get_kgql_model_type.graphql.dart';
import '../documents/get_kgql_model_type_all.graphql.dart';
import '../documents/set_kgql_model_type.graphql.dart';
import '../models/model_type.dart';
import '../requests/set_model_type_request.dart';

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

/// Loads a single [ModelType] by name (e.g. `"Expense"`).
Future<ModelType> fetchKgqlModelTypeByName(
  GraphQLClient client,
  String modelTypeName, {
  Map<String, dynamic>? struct,
  required int domainId,
}) async {
  final result = await client.query(
    QueryOptions(
      document: gql(kgqlGetKgqlModelTypeQuery),
      variables: {
        'input': {
          'model_types': [modelTypeName],
          'struct': struct ?? kgqlFullModelTypeStruct,
        },
        'domainId': domainId,
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

/// All root model types (same query as [modelTypesProvider]).
Future<List<ModelType>> fetchAllModelTypes(
  GraphQLClient client, {
  required int domainId,
}) async {
  final result = await client.query(
    QueryOptions(
      document: gql(getAllModelTypesQuery),
      variables: {'domainId': domainId},
      fetchPolicy: FetchPolicy.networkOnly,
    ),
  );

  if (result.hasException) {
    print('❌ GraphQL Error in getAllModelTypes:');
    print('Exception: ${result.exception}');
    if (result.exception?.graphqlErrors != null) {
      for (var error in result.exception!.graphqlErrors) {
        print('  - ${error.message}');
        if (error.extensions != null) {
          print('    Extensions: ${error.extensions}');
        }
      }
    }
    throw result.exception!;
  }

  final jsonResult = result.data?['getKgqlModelType'];
  if (jsonResult == null) {
    throw Exception('No data returned from getKgqlModelType query');
  }

  final jsonArray = jsonResult is String
      ? json.decode(jsonResult) as List<dynamic>
      : jsonResult as List<dynamic>;

  final allModelTypes = jsonArray.map((rootNode) {
    final rootMap = rootNode as Map<String, dynamic>;
    return ModelType.fromJson(rootMap, recursive: true);
  }).toList();

  print('📊 getAllModelTypes: Received ${allModelTypes.length} root model types');

  return allModelTypes;
}

/// Loads a single [ModelType] by numeric id.
Future<ModelType?> fetchKgqlModelTypeById(
  GraphQLClient client,
  int modelTypeId, {
  required int domainId,
}) async {
  final result = await client.query(
    QueryOptions(
      document: gql(kgqlGetKgqlModelTypeQuery),
      variables: {
        'input': {
          'model_types': [modelTypeId],
          'struct': {
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
          },
        },
        'domainId': domainId,
      },
      fetchPolicy: FetchPolicy.networkOnly,
    ),
  );

  if (result.hasException) {
    print('❌ GraphQL Error in getModelTypeById (id: $modelTypeId):');
    print('Exception: ${result.exception}');
    if (result.exception?.graphqlErrors != null) {
      for (var error in result.exception!.graphqlErrors) {
        print('  - ${error.message}');
        if (error.extensions != null) {
          print('    Extensions: ${error.extensions}');
        }
      }
    }
    throw result.exception!;
  }

  final jsonResult = result.data?['getKgqlModelType'];
  if (jsonResult == null) {
    return null;
  }

  final jsonArray = jsonResult is String
      ? json.decode(jsonResult) as List<dynamic>
      : jsonResult as List<dynamic>;

  if (jsonArray.isEmpty) {
    print('⚠️ Model type with ID $modelTypeId not found');
    return null;
  }

  final modelTypeJson = jsonArray[0] as Map<String, dynamic>;
  return ModelType.fromJson(modelTypeJson, recursive: true);
}

/// Creates or updates a model type via `set_kgql_model_types`.
Future<int> setKgqlModelType(
  GraphQLClient client,
  SetModelTypeRequest request, {
  required int domainId,
}) async {
  final requestJson = request.toJson();

  try {
    final result = await client.mutate(
      MutationOptions(
        document: gql(setKgqlModelTypesMutation),
        variables: {
          'input': {
            'data': requestJson,
            'domainId': domainId,
          },
        },
      ),
    );

    if (result.hasException) {
      print('❌ Mutation Error in setKgqlModelTypes:');
      print('Exception: ${result.exception}');
      if (result.exception?.graphqlErrors != null) {
        for (var error in result.exception!.graphqlErrors) {
          print('  - ${error.message}');
          if (error.extensions != null) {
            print('    Extensions: ${error.extensions}');
          }
        }
      }
      throw result.exception!;
    }

    final responseData = result.data?['setKgqlModelTypes'] as Map<String, dynamic>?;
    if (responseData == null) {
      throw Exception('No data returned from setKgqlModelTypes mutation');
    }

    final jsonResult = responseData['json'];
    final jsonData = jsonResult is String
        ? json.decode(jsonResult) as Map<String, dynamic>
        : jsonResult as Map<String, dynamic>;

    final id = jsonData['id'] as int?;
    if (id == null) {
      throw Exception('No ID returned from setKgqlModelTypes mutation');
    }

    return id;
  } catch (e, stackTrace) {
    print('❌ Exception in setKgqlModelType:');
    print('Error: $e');
    print('Stack trace: $stackTrace');
    rethrow;
  }
}
