import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'dart:convert';
import 'package:nexus_voice_assistant/db.dart';
import 'package:nexus_voice_assistant/models/ModelType.dart';
import 'package:nexus_voice_assistant/models/requests/SetModelTypeRequest.dart';

const String getAllModelTypesQuery = '''
query GetAllModelTypes {
  getKgqlModelType(input: {
    model_types: []
    struct: {
      id: true
      name: true
      type_kind: true
      description: true
      parent: true
      children: true
    }
  })
}
''';


const String getModelTypeByIdQuery = '''
query GetModelTypeById(\$input: JSON!) {
  getKgqlModelType(input: \$input)
}
''';

const String setKgqlModelTypesMutation = '''
mutation SetKgqlModelTypes(\$input: SetKgqlModelTypesInput!) {
  setKgqlModelTypes(input: \$input) {
    json
  }
}
''';

final modelTypesProvider = FutureProvider<List<ModelType>>((ref) async {
  // Router guarantees auth is ready when pages are accessible
  // graphqlClientProvider already watches auth providers
  final client = ref.watch(graphqlClientProvider);
  
  final queryOptions = QueryOptions(
    document: gql(getAllModelTypesQuery),
    fetchPolicy: FetchPolicy.networkOnly, // Don't use cache to ensure fresh data
  );
  
  final result = await client.query(queryOptions);
  
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
  
  // PostGraphile returns raw JSON directly (not wrapped)
  final jsonResult = result.data?['getKgqlModelType'];
  if (jsonResult == null) {
    throw Exception('No data returned from getKgqlModelType query');
  }
  
  final jsonArray = jsonResult is String 
      ? json.decode(jsonResult) as List<dynamic>
      : jsonResult as List<dynamic>;
  
  // Parse root nodes with their nested structure (parent, children, traits)
  final allModelTypes = jsonArray.map((rootNode) {
    final rootMap = rootNode as Map<String, dynamic>;
    // Parse with recursive=true to include nested children
    return ModelType.fromJson(rootMap, recursive: true);
  }).toList();
  
  print('📊 getAllModelTypes: Received ${allModelTypes.length} root model types');
  
  // RLS filters server-side, so no client-side filtering needed
  return allModelTypes;
});

final modelTypeProvider = FutureProvider.family<ModelType?, int>((ref, modelTypeId) async {
  final client = ref.watch(graphqlClientProvider);
  
  // Query directly by ID using get_kgql_model_type (supports integer IDs)
  final queryOptions = QueryOptions(
    document: gql(getModelTypeByIdQuery),
    variables: {
      'input': {
        'model_types': [modelTypeId], // Pass ID as integer in array
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
        },
      },
    },
    fetchPolicy: FetchPolicy.networkOnly,
  );
  
  final result = await client.query(queryOptions);
  
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
  
  // PostGraphile returns raw JSON directly (not wrapped)
  final jsonResult = result.data?['getKgqlModelType'];
  if (jsonResult == null) {
    return null;
  }
  
  final jsonArray = jsonResult is String 
      ? json.decode(jsonResult) as List<dynamic>
      : jsonResult as List<dynamic>;
  
  // Should return exactly one model type (the one we queried by ID)
  if (jsonArray.isEmpty) {
    print('⚠️ Model type with ID $modelTypeId not found');
    return null;
  }
  
  final modelTypeJson = jsonArray[0] as Map<String, dynamic>;
  return ModelType.fromJson(modelTypeJson, recursive: true);
});

/// Creates or updates a model type using set_kgql_model_types.
/// 
/// Takes a [SetModelTypeRequest] that matches the structure expected by
/// set_kgql_model_types function. See: servers/pgdb/docs/human-reference/set_kgql_model_types.md
/// 
/// Returns the ID of the created/updated model type.
Future<int> createModelType(
  ProviderContainer container,
  SetModelTypeRequest request,
) async {
  final client = container.read(graphqlClientProvider);
  
  // Convert request to JSON
  final requestJson = request.toJson();
  
  try {
    // Call set_kgql_model_types mutation
    // PostGraphile wraps JSON functions in input/output structure
    final result = await client.mutate(
      MutationOptions(
        document: gql(setKgqlModelTypesMutation),
        variables: {
          'input': {
            'data': requestJson,
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
    
    // Extract the created/updated model type ID
    // PostGraphile returns JSON result in a 'json' field
    final responseData = result.data?['setKgqlModelTypes'] as Map<String, dynamic>?;
    if (responseData == null) {
      throw Exception('No data returned from setKgqlModelTypes mutation');
    }
    
    // The JSON result is in the 'json' field
    final jsonResult = responseData['json'];
    final jsonData = jsonResult is String 
        ? json.decode(jsonResult) as Map<String, dynamic>
        : jsonResult as Map<String, dynamic>;
    
    final modelTypeId = jsonData['id'] as int?;
    if (modelTypeId == null) {
      throw Exception('No ID returned from setKgqlModelTypes mutation');
    }
    
    return modelTypeId;
  } catch (e, stackTrace) {
    print('❌ Exception in createModelType:');
    print('Error: $e');
    print('Stack trace: $stackTrace');
    rethrow;
  }
}

/// Updates a model type using set_kgql_model_types.
/// 
/// Takes a [SetModelTypeRequest] with an `id` field set.
/// This is the same as createModelType but validates that id is provided.
/// 
/// Returns the ID of the updated model type.
Future<int> updateModelType(
  ProviderContainer container,
  SetModelTypeRequest request,
) async {
  if (request.id == null) {
    throw Exception('id is required for update operations');
  }
  return createModelType(container, request);
}
