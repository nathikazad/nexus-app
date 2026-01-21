import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nexus_voice_assistant/models/ModelType.dart';
import 'dart:convert';
import 'package:nexus_voice_assistant/providers/model_types_provider.dart';
import 'package:nexus_voice_assistant/auth.dart';
import 'package:nexus_voice_assistant/models/requests/SetModelTypeRequest.dart';
import 'package:nexus_voice_assistant/db.dart';

// Custom AuthController for testing that returns user immediately
class TestAuthController extends AuthController {
  @override
  Future<User?> build() async {
    // Return user immediately without SharedPreferences delay
    return User(userId: '1', endpoint: 'http://localhost:5001/graphql');
  }
}

void main() {
  test('Create a basic model type and verify it returns an ID', () async {
    print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('🧪 TEST: Create basic model type');
    print('   Connecting to: http://localhost:5001/graphql');
    print('   User ID: 1');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

    // Create a container with overrides to use real GraphQL endpoint
    final container = ProviderContainer(
      overrides: [
        // Override authProvider to use TestAuthController
        authProvider.overrideWith(() => TestAuthController()),
      ],
    );

    try {
      // Wait for auth provider to be ready
      await container.read(authProvider.future);
      
      print('✅ Auth provider ready');
      print('📞 Creating model type...\n');
      
      // Create a basic model type request
      final request = SetModelTypeRequest(
        name: 'TestModelType_${DateTime.now().millisecondsSinceEpoch}',
        typeKind: 'base',
        description: 'A test model type created by automated test',
      );
      
      print('Request JSON:');
      final encoder = JsonEncoder.withIndent('  ');
      print(encoder.convert(request.toJson()));
      print('');
      
      // Call createModelType
      final modelTypeId = await createModelType(container, request);
      
      print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('✅ CREATE RESULT:');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
      print('Created model type ID: $modelTypeId\n');
      
      // Verify the ID is valid
      expect(modelTypeId, isA<int>(), reason: 'Model type ID should be an integer');
      expect(modelTypeId, greaterThan(0), reason: 'Model type ID should be greater than 0');
      
      print('✅ Test passed! Model type created successfully with ID: $modelTypeId');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
      
    } catch (e, stackTrace) {
      // If there's an error, print it
      print('\n❌ ERROR occurred:');
      print('Exception: $e');
      print('Stack trace: $stackTrace');
      print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
      rethrow;
    }

    container.dispose();
  });

  test('Update model type description', () async {
    print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('🧪 TEST: Update model type description');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(() => TestAuthController()),
      ],
    );

    try {
      await container.read(authProvider.future);
      
      // Create a model type first
      final createRequest = SetModelTypeRequest(
        name: 'TestUpdateType_${DateTime.now().millisecondsSinceEpoch}',
        typeKind: 'base',
        description: 'Original description',
      );
      
      final modelTypeId = await createModelType(container, createRequest);
      print('✅ Created model type with ID: $modelTypeId');
      
      // Update description
      final updateRequest = SetModelTypeRequest(
        id: modelTypeId,
        name: createRequest.name,
        typeKind: 'base',
        description: 'Updated description',
      );
      
      print('\nUpdate Request JSON:');
      final encoder = JsonEncoder.withIndent('  ');
      print(encoder.convert(updateRequest.toJson()));
      print('');
      
      final updatedId = await updateModelType(container, updateRequest);
      expect(updatedId, modelTypeId);
      
      print('✅ Model type updated successfully');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
      
    } catch (e, stackTrace) {
      print('\n❌ ERROR occurred:');
      print('Exception: $e');
      print('Stack trace: $stackTrace');
      print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
      rethrow;
    }

    container.dispose();
  });

  test('Update attribute definition', () async {
    print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('🧪 TEST: Update attribute definition');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(() => TestAuthController()),
      ],
    );

    try {
      await container.read(authProvider.future);
      
      final client = container.read(graphqlClientProvider);
      
      // Create a model type with attribute definitions
      final createRequest = SetModelTypeRequest(
        name: 'TestAttrUpdate_${DateTime.now().millisecondsSinceEpoch}',
        typeKind: 'base',
        attributeDefinitions: [
          AttributeDefinition(
            key: 'email',
            valueType: 'string',
            required: true,
          ),
          AttributeDefinition(
            key: 'age',
            valueType: 'number',
            required: false,
          ),
        ],
      );
      
      final modelTypeId = await createModelType(container, createRequest);
      print('✅ Created model type with ID: $modelTypeId');
      
      // Query to get attribute definition IDs
      const queryAttrDefs = '''
        query GetAttributeDefinitions(\$modelTypeId: Int!) {
          allAttributeDefinitions(condition: { modelTypeId: \$modelTypeId }) {
            nodes {
              id
              key
              valueType
              required
            }
          }
        }
      ''';
      
      final queryResult = await client.query(
        QueryOptions(
          document: gql(queryAttrDefs),
          variables: {'modelTypeId': modelTypeId},
        ),
      );
      
      final nodes = queryResult.data?['allAttributeDefinitions']?['nodes'] as List<dynamic>?;
      expect(nodes, isNotNull);
      expect(nodes!.length, 2);
      
      final emailAttr = nodes.firstWhere((n) => n['key'] == 'email');
      final ageAttr = nodes.firstWhere((n) => n['key'] == 'age');
      
      final emailAttrId = emailAttr['id'] as int;
      final ageAttrId = ageAttr['id'] as int;
      
      print('Found attribute IDs: email=$emailAttrId, age=$ageAttrId');
      
      // Update attribute definitions
      final updateRequest = SetModelTypeRequest(
        id: modelTypeId,
        name: createRequest.name,
        typeKind: 'base',
        attributeDefinitions: [
          AttributeDefinition(
            id: emailAttrId,
            key: 'email',
            valueType: 'string',
            required: false, // Changed from true
          ),
          AttributeDefinition(
            id: ageAttrId,
            key: 'age',
            valueType: 'number',
            required: true, // Changed from false
            constraints: {'min': 0, 'max': 150}, // Added constraints
          ),
        ],
      );
      
      print('\nUpdate Request JSON:');
      final encoder = JsonEncoder.withIndent('  ');
      print(encoder.convert(updateRequest.toJson()));
      print('');
      
      final updatedId = await updateModelType(container, updateRequest);
      expect(updatedId, modelTypeId);
      
      print('✅ Attribute definitions updated successfully');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
      
    } catch (e, stackTrace) {
      print('\n❌ ERROR occurred:');
      print('Exception: $e');
      print('Stack trace: $stackTrace');
      print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
      rethrow;
    }

    container.dispose();
  });

  test('Delete attribute definition', () async {
    print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('🧪 TEST: Delete attribute definition');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(() => TestAuthController()),
      ],
    );

    try {
      await container.read(authProvider.future);
      
      final client = container.read(graphqlClientProvider);
      
      // Create a model type with attribute definitions
      final createRequest = SetModelTypeRequest(
        name: 'TestAttrDelete_${DateTime.now().millisecondsSinceEpoch}',
        typeKind: 'base',
        attributeDefinitions: [
          AttributeDefinition(key: 'email', valueType: 'string', required: true),
          AttributeDefinition(key: 'age', valueType: 'number', required: false),
          AttributeDefinition(key: 'phone', valueType: 'string', required: false),
        ],
      );
      
      final modelTypeId = await createModelType(container, createRequest);
      print('✅ Created model type with ID: $modelTypeId');
      
      // Query to get attribute definition ID to delete
      const queryAttrDefs = '''
        query GetAttributeDefinitions(\$modelTypeId: Int!) {
          allAttributeDefinitions(condition: { modelTypeId: \$modelTypeId }) {
            nodes {
              id
              key
            }
          }
        }
      ''';
      
      final queryResult = await client.query(
        QueryOptions(
          document: gql(queryAttrDefs),
          variables: {'modelTypeId': modelTypeId},
        ),
      );
      
      final nodes = queryResult.data?['allAttributeDefinitions']?['nodes'] as List<dynamic>?;
      final phoneAttr = nodes?.firstWhere((n) => n['key'] == 'phone');
      final phoneAttrId = phoneAttr?['id'] as int;
      
      expect(phoneAttrId, isNotNull);
      print('Found phone attribute ID: $phoneAttrId');
      
      // Delete phone attribute definition
      final deleteRequest = SetModelTypeRequest(
        id: modelTypeId,
        name: createRequest.name,
        typeKind: 'base',
        attributeDefinitions: [
          AttributeDefinition(id: phoneAttrId, delete: true),
        ],
      );
      
      print('\nDelete Request JSON:');
      final encoder = JsonEncoder.withIndent('  ');
      print(encoder.convert(deleteRequest.toJson()));
      print('');
      
      final updatedId = await updateModelType(container, deleteRequest);
      expect(updatedId, modelTypeId);
      
      print('✅ Attribute definition deleted successfully');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
      
    } catch (e, stackTrace) {
      print('\n❌ ERROR occurred:');
      print('Exception: $e');
      print('Stack trace: $stackTrace');
      print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
      rethrow;
    }

    container.dispose();
  });

  test('Mixed update and delete attribute definitions', () async {
    print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('🧪 TEST: Mixed update and delete attribute definitions');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(() => TestAuthController()),
      ],
    );

    try {
      await container.read(authProvider.future);
      
      final client = container.read(graphqlClientProvider);
      
      // Create a model type with attribute definitions
      final createRequest = SetModelTypeRequest(
        name: 'TestAttrMixed_${DateTime.now().millisecondsSinceEpoch}',
        typeKind: 'base',
        attributeDefinitions: [
          AttributeDefinition(key: 'email', valueType: 'string', required: true),
          AttributeDefinition(key: 'age', valueType: 'number', required: false),
        ],
      );
      
      final modelTypeId = await createModelType(container, createRequest);
      print('✅ Created model type with ID: $modelTypeId');
      
      // Query to get attribute definition IDs
      const queryAttrDefs = '''
        query GetAttributeDefinitions(\$modelTypeId: Int!) {
          allAttributeDefinitions(condition: { modelTypeId: \$modelTypeId }) {
            nodes {
              id
              key
            }
          }
        }
      ''';
      
      final queryResult = await client.query(
        QueryOptions(
          document: gql(queryAttrDefs),
          variables: {'modelTypeId': modelTypeId},
        ),
      );
      
      final nodes = queryResult.data?['allAttributeDefinitions']?['nodes'] as List<dynamic>?;
      final emailAttr = nodes?.firstWhere((n) => n['key'] == 'email');
      final ageAttr = nodes?.firstWhere((n) => n['key'] == 'age');
      
      final emailAttrId = emailAttr?['id'] as int;
      final ageAttrId = ageAttr?['id'] as int;
      
      print('Found attribute IDs: email=$emailAttrId, age=$ageAttrId');
      
      // Mix: edit email, delete age, create phone
      final mixedRequest = SetModelTypeRequest(
        id: modelTypeId,
        name: createRequest.name,
        typeKind: 'base',
        attributeDefinitions: [
          AttributeDefinition(
            id: emailAttrId,
            key: 'email',
            valueType: 'string',
            required: false, // Changed from true
          ),
          AttributeDefinition(id: ageAttrId, delete: true), // Delete
          AttributeDefinition(
            key: 'phone',
            valueType: 'string',
            required: false,
          ), // Create new
        ],
      );
      
      print('\nMixed Request JSON:');
      final encoder = JsonEncoder.withIndent('  ');
      print(encoder.convert(mixedRequest.toJson()));
      print('');
      
      final updatedId = await updateModelType(container, mixedRequest);
      expect(updatedId, modelTypeId);
      
      print('✅ Mixed update/delete/create operations completed successfully');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
      
    } catch (e, stackTrace) {
      print('\n❌ ERROR occurred:');
      print('Exception: $e');
      print('Stack trace: $stackTrace');
      print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
      rethrow;
    }

    container.dispose();
  });

  test('Update relationship type', () async {
    print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('🧪 TEST: Update relationship type');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(() => TestAuthController()),
      ],
    );

    try {
      await container.read(authProvider.future);
      
      final client = container.read(graphqlClientProvider);
      
      // Create Company first
      final companyRequest = SetModelTypeRequest(
        name: 'Company_${DateTime.now().millisecondsSinceEpoch}',
        typeKind: 'base',
      );
      final companyId = await createModelType(container, companyRequest);
      print('✅ Created Company with ID: $companyId');
      
      // Create Person with relationship to Company
      final createRequest = SetModelTypeRequest(
        name: 'Person_${DateTime.now().millisecondsSinceEpoch}',
        typeKind: 'base',
        relationshipTypes: [
          RelationshipType.fromName(
            companyRequest.name,
            multiplicity: 'many',
            description: 'Person works for company',
          ),
        ],
      );
      
      final personId = await createModelType(container, createRequest);
      print('✅ Created Person with ID: $personId');
      
      // Query to get relationship type ID
      const queryRelTypes = '''
        query GetRelationshipTypes(\$fromModelTypeId: Int!) {
          allRelationshipTypes(condition: { fromModelTypeId: \$fromModelTypeId }) {
            nodes {
              id
              multiplicity
              description
            }
          }
        }
      ''';
      
      final queryResult = await client.query(
        QueryOptions(
          document: gql(queryRelTypes),
          variables: {'fromModelTypeId': personId},
        ),
      );
      
      final nodes = queryResult.data?['allRelationshipTypes']?['nodes'] as List<dynamic>?;
      expect(nodes, isNotNull);
      expect(nodes!.length, 1);
      
      final relTypeId = nodes[0]['id'] as int;
      print('Found relationship type ID: $relTypeId');
      
      // Update relationship type
      final updateRequest = SetModelTypeRequest(
        id: personId,
        name: createRequest.name,
        typeKind: 'base',
        relationshipTypes: [
          RelationshipType(
            id: relTypeId,
            multiplicity: 'one', // Changed from 'many'
            description: 'Updated description', // Changed description
            // Note: link field cannot be changed when editing
          ),
        ],
      );
      
      print('\nUpdate Request JSON:');
      final encoder = JsonEncoder.withIndent('  ');
      print(encoder.convert(updateRequest.toJson()));
      print('');
      
      final updatedId = await updateModelType(container, updateRequest);
      expect(updatedId, personId);
      
      print('✅ Relationship type updated successfully');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
      
    } catch (e, stackTrace) {
      print('\n❌ ERROR occurred:');
      print('Exception: $e');
      print('Stack trace: $stackTrace');
      print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
      rethrow;
    }

    container.dispose();
  });

  test('Delete relationship type', () async {
    print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('🧪 TEST: Delete relationship type');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(() => TestAuthController()),
      ],
    );

    try {
      await container.read(authProvider.future);
      
      final client = container.read(graphqlClientProvider);
      
      // Create Company and Contact
      final companyRequest = SetModelTypeRequest(
        name: 'Company_${DateTime.now().millisecondsSinceEpoch}',
        typeKind: 'base',
      );
      final companyId = await createModelType(container, companyRequest);
      
      final contactRequest = SetModelTypeRequest(
        name: 'Contact_${DateTime.now().millisecondsSinceEpoch}',
        typeKind: 'base',
      );
      final contactId = await createModelType(container, contactRequest);
      
      print('✅ Created Company ($companyId) and Contact ($contactId)');
      
      // Create Person with relationships
      final createRequest = SetModelTypeRequest(
        name: 'Person_${DateTime.now().millisecondsSinceEpoch}',
        typeKind: 'base',
        relationshipTypes: [
          RelationshipType.fromName(companyRequest.name, multiplicity: 'many'),
          RelationshipType.fromName(contactRequest.name, multiplicity: 'many'),
        ],
      );
      
      final personId = await createModelType(container, createRequest);
      print('✅ Created Person with ID: $personId');
      
      // Query to get relationship type ID to delete
      const queryRelTypes = '''
        query GetRelationshipTypes(\$fromModelTypeId: Int!, \$toModelTypeId: Int!) {
          allRelationshipTypes(
            condition: { fromModelTypeId: \$fromModelTypeId, toModelTypeId: \$toModelTypeId }
          ) {
            nodes {
              id
            }
          }
        }
      ''';
      
      final queryResult = await client.query(
        QueryOptions(
          document: gql(queryRelTypes),
          variables: {'fromModelTypeId': personId, 'toModelTypeId': contactId},
        ),
      );
      
      final nodes = queryResult.data?['allRelationshipTypes']?['nodes'] as List<dynamic>?;
      expect(nodes, isNotNull);
      expect(nodes!.length, 1);
      
      final relTypeId = nodes[0]['id'] as int;
      print('Found relationship type ID to delete: $relTypeId');
      
      // Delete relationship type
      final deleteRequest = SetModelTypeRequest(
        id: personId,
        name: createRequest.name,
        typeKind: 'base',
        relationshipTypes: [
          RelationshipType(id: relTypeId, delete: true),
        ],
      );
      
      print('\nDelete Request JSON:');
      final encoder = JsonEncoder.withIndent('  ');
      print(encoder.convert(deleteRequest.toJson()));
      print('');
      
      final updatedId = await updateModelType(container, deleteRequest);
      expect(updatedId, personId);
      
      print('✅ Relationship type deleted successfully');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
      
    } catch (e, stackTrace) {
      print('\n❌ ERROR occurred:');
      print('Exception: $e');
      print('Stack trace: $stackTrace');
      print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
      rethrow;
    }

    container.dispose();
  });

  test('Mixed update and delete relationship types', () async {
    print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('🧪 TEST: Mixed update and delete relationship types');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(() => TestAuthController()),
      ],
    );

    try {
      await container.read(authProvider.future);
      
      final client = container.read(graphqlClientProvider);
      
      // Create Company, Contact, and Address
      final companyRequest = SetModelTypeRequest(
        name: 'Company_${DateTime.now().millisecondsSinceEpoch}',
        typeKind: 'base',
      );
      final companyId = await createModelType(container, companyRequest);
      
      final contactRequest = SetModelTypeRequest(
        name: 'Contact_${DateTime.now().millisecondsSinceEpoch}',
        typeKind: 'base',
      );
      final contactId = await createModelType(container, contactRequest);
      
      final addressRequest = SetModelTypeRequest(
        name: 'Address_${DateTime.now().millisecondsSinceEpoch}',
        typeKind: 'base',
      );
      final addressId = await createModelType(container, addressRequest);
      
      print('✅ Created Company ($companyId), Contact ($contactId), Address ($addressId)');
      
      // Create Person with relationships
      final createRequest = SetModelTypeRequest(
        name: 'Person_${DateTime.now().millisecondsSinceEpoch}',
        typeKind: 'base',
        relationshipTypes: [
          RelationshipType.fromName(companyRequest.name, multiplicity: 'many'),
          RelationshipType.fromName(contactRequest.name, multiplicity: 'many'),
        ],
      );
      
      final personId = await createModelType(container, createRequest);
      print('✅ Created Person with ID: $personId');
      
      // Query to get relationship type IDs
      const queryRelTypes = '''
        query GetRelationshipTypes(\$fromModelTypeId: Int!) {
          allRelationshipTypes(condition: { fromModelTypeId: \$fromModelTypeId }) {
            nodes {
              id
              toModelTypeId
            }
          }
        }
      ''';
      
      final queryResult = await client.query(
        QueryOptions(
          document: gql(queryRelTypes),
          variables: {'fromModelTypeId': personId},
        ),
      );
      
      final nodes = queryResult.data?['allRelationshipTypes']?['nodes'] as List<dynamic>?;
      expect(nodes, isNotNull);
      expect(nodes!.length, 2);
      
      final companyRel = nodes.firstWhere((n) => n['toModelTypeId'] == companyId);
      final contactRel = nodes.firstWhere((n) => n['toModelTypeId'] == contactId);
      
      final companyRelId = companyRel['id'] as int;
      final contactRelId = contactRel['id'] as int;
      
      print('Found relationship IDs: Company=$companyRelId, Contact=$contactRelId');
      
      // Mix: edit Company relationship, delete Contact relationship, create Address relationship
      final mixedRequest = SetModelTypeRequest(
        id: personId,
        name: createRequest.name,
        typeKind: 'base',
        relationshipTypes: [
          RelationshipType(
            id: companyRelId,
            multiplicity: 'one', // Edit: changed from 'many'
          ),
          RelationshipType(id: contactRelId, delete: true), // Delete
          RelationshipType.fromName(
            addressRequest.name,
            multiplicity: 'many',
          ), // Create new
        ],
      );
      
      print('\nMixed Request JSON:');
      final encoder = JsonEncoder.withIndent('  ');
      print(encoder.convert(mixedRequest.toJson()));
      print('');
      
      final updatedId = await updateModelType(container, mixedRequest);
      expect(updatedId, personId);
      
      print('✅ Mixed update/delete/create relationship operations completed successfully');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
      
    } catch (e, stackTrace) {
      print('\n❌ ERROR occurred:');
      print('Exception: $e');
      print('Stack trace: $stackTrace');
      print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
      rethrow;
    }

    container.dispose();
  });
}

