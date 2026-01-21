import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'dart:convert';
import 'package:nexus_voice_assistant/db.dart';
import 'package:nexus_voice_assistant/models/Model.dart';
import 'package:nexus_voice_assistant/models/requests/SetModelRequest.dart';

const String getModelsByModelTypeIdQuery = '''
query GetModelsByModelTypeId(\$filter: JSON!, \$struct: JSON!) {
  getKgqlModels(filter: \$filter, struct: \$struct)
}
''';

const String getModelByIdQuery = '''
query GetModelById(\$filter: JSON!, \$struct: JSON!) {
  getKgqlModels(filter: \$filter, struct: \$struct)
}
''';

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
    document: gql(getModelsByModelTypeIdQuery),
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
    print('❌ GraphQL Error in getModelsByModelTypeId (modelTypeId: $modelTypeId):');
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
  
  // PostGraphile returns raw JSON directly (not wrapped)
  final jsonResult = result.data?['getKgqlModels'];
  if (jsonResult == null) {
    return [];
  }
  
  final jsonArray = jsonResult is String 
      ? json.decode(jsonResult) as List<dynamic>
      : jsonResult as List<dynamic>;
  
  // Parse models from JSON array
  final models = jsonArray.map((modelJson) {
    if (modelJson is Map<String, dynamic>) {
      return Model.fromJson(modelJson);
    }
    return null;
  }).whereType<Model>().toList();
  
  // Filter by modelTypeId as a safety check (should already be filtered by model_type name)
  return models.where((model) => model.modelTypeId == modelTypeId).toList();
});

final modelProvider = FutureProvider.family<Model?, int>((ref, modelId) async {
  final client = ref.watch(graphqlClientProvider);
  
  final queryOptions = QueryOptions(
    document: gql(getModelByIdQuery),
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
    print('❌ GraphQL Error in getModelById (id: $modelId):');
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
  
  // PostGraphile returns raw JSON directly (not wrapped)
  final jsonResult = result.data?['getKgqlModels'];
  if (jsonResult == null) {
    return null;
  }
  
  final jsonArray = jsonResult is String 
      ? json.decode(jsonResult) as List<dynamic>
      : jsonResult as List<dynamic>;
  
  // Should return exactly one model (the one we queried by ID)
  if (jsonArray.isEmpty) {
    print('⚠️ Model with ID $modelId not found');
    return null;
  }
  
  final modelJson = jsonArray[0] as Map<String, dynamic>;
  return Model.fromJson(modelJson);
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
  
  try {
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
      print('❌ Mutation Error in setKgqlModels:');
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
    
    // Extract the created/updated model ID
    // PostGraphile returns JSON result in a 'json' field
    final responseData = result.data?['setKgqlModels'] as Map<String, dynamic>?;
    if (responseData == null) {
      throw Exception('No data returned from setKgqlModels mutation');
    }
    
    // The JSON result is in the 'json' field
    final jsonResult = responseData['json'];
    final jsonData = jsonResult is String 
        ? json.decode(jsonResult) as Map<String, dynamic>
        : jsonResult as Map<String, dynamic>;
    
    final modelId = jsonData['id'] as int?;
    if (modelId == null) {
      throw Exception('No ID returned from setKgqlModels mutation');
    }
    
    return modelId;
  } catch (e, stackTrace) {
    print('❌ Error in createModel:');
    print('Exception: $e');
    print('Stack trace: $stackTrace');
    rethrow;
  }
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

