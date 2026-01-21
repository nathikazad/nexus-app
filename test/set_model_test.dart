import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nexus_voice_assistant/models/ModelType.dart';
import 'dart:convert';
import 'package:nexus_voice_assistant/data_providers/models_provider.dart';
import 'package:nexus_voice_assistant/auth.dart';
import 'package:nexus_voice_assistant/models/requests/SetModelRequest.dart';
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
  test('Create Person model with age and Company relation, then update and delete', () async {
    print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('🧪 TEST: Create, update, and delete model attributes/relations');
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
      
      // Step 1: Query for Person model type to get its ID and available attributes/relations
      print('\n📋 Step 1: Querying Person model type...');
      
      // Person might be nested, so we need to search recursively or query by name
      // Let's use a GraphQL query to find Person by name
      final client = container.read(graphqlClientProvider);
      final getModelTypeByNameQuery = '''
        query GetModelTypeByName(\$input: JSON!) {
          getKgqlModelType(input: \$input)
        }
      ''';
      
      final modelTypeResult = await client.query(
        QueryOptions(
          document: gql(getModelTypeByNameQuery),
          variables: {
            'input': {
              'model_types': ['Person'], // Query by name
              'struct': {
                'id': true,
                'name': true,
                'type_kind': true,
                'description': true,
                'attributes': true,
                'relations': true,
              },
            },
          },
          fetchPolicy: FetchPolicy.networkOnly,
        ),
      );
      
      if (modelTypeResult.hasException) {
        throw Exception('Failed to query Person model type: ${modelTypeResult.exception}');
      }
      
      final modelTypeJson = modelTypeResult.data?['getKgqlModelType'];
      if (modelTypeJson == null) {
        throw Exception('Person model type not found');
      }
      
      final modelTypeArray = modelTypeJson is String 
          ? json.decode(modelTypeJson) as List<dynamic>
          : modelTypeJson as List<dynamic>;
      
      if (modelTypeArray.isEmpty) {
        throw Exception('Person model type not found');
      }
      
      final personModelTypeDetails = ModelType.fromJson(modelTypeArray[0] as Map<String, dynamic>, recursive: true);
      
      print('   Attributes: ${personModelTypeDetails.attributes?.length ?? 0}');
      if (personModelTypeDetails.attributes != null) {
        for (var attr in personModelTypeDetails.attributes!) {
          print('     - ${attr.key} (${attr.valueType})');
        }
      }
      
      print('   Relations: ${personModelTypeDetails.relations?.length ?? 0}');
      if (personModelTypeDetails.relations != null) {
        for (var rel in personModelTypeDetails.relations!) {
          print('     - ${rel.link}');
        }
      }
      
      // Find the "age" attribute
      final ageAttribute = personModelTypeDetails.attributes?.firstWhere(
        (attr) => attr.key == 'age',
        orElse: () => throw Exception('age attribute not found for Person'),
      );
      print('✅ Found age attribute: key=${ageAttribute?.key}, valueType=${ageAttribute?.valueType}');
      
      // Check available relations
      print('   Available relations for Person:');
      if (personModelTypeDetails.relations != null) {
        for (var rel in personModelTypeDetails.relations!) {
          print('     - ${rel.link}');
        }
      }
      
      // Note: We'll try to create a Company relation even if it's not in the relationship types
      // The backend will handle it if the relationship type exists
      print('✅ Will attempt to create Company relation');
      
      // Step 2: Query for Company models to find Apple and Microsoft
      print('\n📋 Step 2: Querying Company models...');
      
      // Query Company model type by name
      final companyModelTypeResult = await client.query(
        QueryOptions(
          document: gql(getModelTypeByNameQuery),
          variables: {
            'input': {
              'model_types': ['Company'],
              'struct': {
                'id': true,
                'name': true,
              },
            },
          },
          fetchPolicy: FetchPolicy.networkOnly,
        ),
      );
      
      if (companyModelTypeResult.hasException) {
        throw Exception('Failed to query Company model type: ${companyModelTypeResult.exception}');
      }
      
      final companyModelTypeJson = companyModelTypeResult.data?['getKgqlModelType'];
      final companyModelTypeArray = companyModelTypeJson is String 
          ? json.decode(companyModelTypeJson) as List<dynamic>
          : companyModelTypeJson as List<dynamic>;
      
      if (companyModelTypeArray.isEmpty) {
        throw Exception('Company model type not found');
      }
      
      final companyModelType = ModelType.fromJson(companyModelTypeArray[0] as Map<String, dynamic>, recursive: false);
      
      // Query for Company models
      final companyModels = await container.read(modelsProvider(companyModelType.id).future);
      print('✅ Found ${companyModels.length} Company models');
      
      final appleModel = companyModels.firstWhere(
        (m) => m.name.toLowerCase().contains('apple'),
        orElse: () => throw Exception('Apple model not found'),
      );
      print('✅ Found Apple: ID=${appleModel.id}, Name=${appleModel.name}');
      
      final microsoftModel = companyModels.firstWhere(
        (m) => m.name.toLowerCase().contains('microsoft'),
        orElse: () => throw Exception('Microsoft model not found'),
      );
      print('✅ Found Microsoft: ID=${microsoftModel.id}, Name=${microsoftModel.name}');
      
      // Step 3: Create Person model with age attribute and relation to Apple
      print('\n📋 Step 3: Creating Person model with age and Apple relation...');
      final createRequest = SetModelRequest(
        modelType: 'Person',
        name: 'TestPerson_${DateTime.now().millisecondsSinceEpoch}',
        attributes: [
          ModelAttribute(key: 'age', value: 25),
        ],
        relations: [
          ModelRelation(
            modelType: 'Company',
            link: [appleModel.id],
          ),
        ],
      );
      
      print('Create Request JSON:');
      final encoder = JsonEncoder.withIndent('  ');
      print(encoder.convert(createRequest.toJson()));
      print('');
      
      final createdModelId = await createModel(container, createRequest);
      print('✅ Created Person model with ID: $createdModelId');
      
      // Verify the model was created
      final createdModel = await container.read(modelProvider(createdModelId).future);
      if (createdModel == null) {
        throw Exception('Created model not found');
      }
      
      print('✅ Verified model: ${createdModel.name}');
      print('   Attributes: ${createdModel.attributesList?.length ?? 0}');
      if (createdModel.attributesList != null) {
        for (var attr in createdModel.attributesList!) {
          print('     - ${attr.key}: ${attr.value}');
        }
      }
      print('   Relations: ${createdModel.relationsList?.length ?? 0}');
      if (createdModel.relationsList != null) {
        for (var rel in createdModel.relationsList!) {
          print('     - ${rel.modelType}: ${rel.name} (model_id=${rel.modelId})');
        }
      }
      
      // Verify age attribute exists
      final ageAttr = createdModel.attributesList?.firstWhere(
        (attr) => attr.key == 'age',
      );
      if (ageAttr == null) {
        throw Exception('age attribute not found in created model');
      }
      // Age value might be returned as string from database
      final ageValue = ageAttr.value is String ? int.parse(ageAttr.value as String) : ageAttr.value;
      expect(ageValue, 25, reason: 'age should be 25');
      print('✅ Verified age attribute: $ageValue');
      
      // Verify Apple relation exists
      final appleRel = createdModel.relationsList?.firstWhere(
        (rel) => rel.modelId == appleModel.id,
      );
      if (appleRel == null) {
        throw Exception('Apple relation not found in created model');
      }
      expect(appleRel.modelId, appleModel.id, reason: 'Apple relation should exist');
      print('✅ Verified Apple relation: model_id=${appleRel.modelId}');
      
      // Step 4: Update age and change company to Microsoft
      print('\n📋 Step 4: Updating age and changing company to Microsoft...');
      
      // First, we need to get the relation ID for the Apple relation
      final updatedModel = await container.read(modelProvider(createdModelId).future);
      if (updatedModel == null) {
        throw Exception('Model not found for update');
      }
      
      final appleRelationId = updatedModel.relationsList?.firstWhere(
        (rel) => rel.modelId == appleModel.id,
      ).relationId;
      
      if (appleRelationId == null) {
        throw Exception('Could not find Apple relation ID');
      }
      print('   Found Apple relation ID: $appleRelationId');
      
      final updateRequest = SetModelRequest(
        id: createdModelId,
        name: createdModel.name,
        attributes: [
          ModelAttribute(key: 'age', value: 30), // Update age to 30
        ],
        relations: [
          ModelRelation(
            id: appleRelationId,
            delete: true, // Delete Apple relation
          ),
          ModelRelation(
            modelType: 'Company',
            link: [microsoftModel.id], // Add Microsoft relation
          ),
        ],
      );
      
      print('Update Request JSON:');
      print(encoder.convert(updateRequest.toJson()));
      print('');
      
      final updatedModelId = await updateModel(container, updateRequest);
      expect(updatedModelId, createdModelId, reason: 'Updated model ID should match');
      print('✅ Updated model successfully');
      
      // Invalidate the provider cache to ensure fresh data
      container.invalidate(modelProvider(createdModelId));
      
      // Wait a bit for the update to propagate
      await Future.delayed(Duration(milliseconds: 500));
      
      // Verify the update
      final verifyModel1 = await container.read(modelProvider(createdModelId).future);
      if (verifyModel1 == null) {
        throw Exception('Model not found after update');
      }
      
      final updatedAgeAttr = verifyModel1.attributesList?.firstWhere(
        (attr) => attr.key == 'age',
        orElse: () => throw Exception('age attribute not found after update'),
      );
      if (updatedAgeAttr == null) {
        throw Exception('age attribute not found after update');
      }
      // Age value might be returned as string from database
      final updatedAgeValue = updatedAgeAttr.value is String ? int.parse(updatedAgeAttr.value as String) : updatedAgeAttr.value;
      expect(updatedAgeValue, 30, reason: 'age should be updated to 30');
      print('✅ Verified age updated to: $updatedAgeValue');
      
      final microsoftRel = verifyModel1.relationsList?.firstWhere(
        (rel) => rel.modelId == microsoftModel.id,
        orElse: () => throw Exception('Microsoft relation not found after update'),
      );
      expect(microsoftRel?.modelId, microsoftModel.id, reason: 'Microsoft relation should exist');
      print('✅ Verified Microsoft relation: model_id=${microsoftRel?.modelId}');
      
      // Verify Apple relation is deleted
      final appleRelAfterUpdate = verifyModel1.relationsList?.where(
        (rel) => rel.modelId == appleModel.id,
      ).firstOrNull;
      expect(appleRelAfterUpdate, isNull, reason: 'Apple relation should be deleted');
      print('✅ Verified Apple relation deleted');
      
      // Step 5: Delete age attribute
      print('\n📋 Step 5: Deleting age attribute...');
      
      final deleteAgeRequest = SetModelRequest(
        id: createdModelId,
        name: verifyModel1.name,
        attributes: [
          ModelAttribute(key: 'age', delete: true),
        ],
      );
      
      print('Delete Age Request JSON:');
      print(encoder.convert(deleteAgeRequest.toJson()));
      print('');
      
      final deleteAgeModelId = await updateModel(container, deleteAgeRequest);
      expect(deleteAgeModelId, createdModelId, reason: 'Model ID should remain the same');
      print('✅ Deleted age attribute');
      
      // Invalidate the provider cache to ensure fresh data
      container.invalidate(modelProvider(createdModelId));
      await Future.delayed(Duration(milliseconds: 500));
      
      // Verify age attribute is deleted
      final verifyModel2 = await container.read(modelProvider(createdModelId).future);
      if (verifyModel2 == null) {
        throw Exception('Model not found after deleting age');
      }
      
      final ageAfterDelete = verifyModel2.attributesList?.where(
        (attr) => attr.key == 'age',
      ).firstOrNull;
      expect(ageAfterDelete, isNull, reason: 'age attribute should be deleted');
      print('✅ Verified age attribute deleted');
      
      // Step 6: Delete Company relation
      print('\n📋 Step 6: Deleting Company relation...');
      
      // Get the Microsoft relation ID
      final verifyModel3 = await container.read(modelProvider(createdModelId).future);
      if (verifyModel3 == null) {
        throw Exception('Model not found before deleting relation');
      }
      
      final microsoftRelationId = verifyModel3.relationsList?.firstWhere(
        (rel) => rel.modelId == microsoftModel.id,
      ).relationId;
      
      if (microsoftRelationId == null) {
        throw Exception('Could not find Microsoft relation ID');
      }
      print('   Found Microsoft relation ID: $microsoftRelationId');
      
      final deleteRelationRequest = SetModelRequest(
        id: createdModelId,
        name: verifyModel3.name,
        relations: [
          ModelRelation(
            id: microsoftRelationId,
            delete: true,
          ),
        ],
      );
      
      print('Delete Relation Request JSON:');
      print(encoder.convert(deleteRelationRequest.toJson()));
      print('');
      
      final deleteRelationModelId = await updateModel(container, deleteRelationRequest);
      expect(deleteRelationModelId, createdModelId, reason: 'Model ID should remain the same');
      print('✅ Deleted Company relation');
      
      // Invalidate the provider cache to ensure fresh data
      container.invalidate(modelProvider(createdModelId));
      await Future.delayed(Duration(milliseconds: 500));
      
      // Verify Company relation is deleted
      final verifyModel4 = await container.read(modelProvider(createdModelId).future);
      if (verifyModel4 == null) {
        throw Exception('Model not found after deleting relation');
      }
      
      final microsoftRelAfterDelete = verifyModel4.relationsList?.where(
        (rel) => rel.modelId == microsoftModel.id,
      ).firstOrNull;
      expect(microsoftRelAfterDelete, isNull, reason: 'Microsoft relation should be deleted');
      print('✅ Verified Company relation deleted');
      
      print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('✅ ALL TESTS PASSED!');
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
}

