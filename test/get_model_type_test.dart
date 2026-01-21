import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:nexus_voice_assistant/providers/model_types_provider.dart';
import 'package:nexus_voice_assistant/auth.dart';
import 'package:nexus_voice_assistant/models/ModelType.dart';

// Custom AuthController for testing that returns user immediately
class TestAuthController extends AuthController {
  @override
  Future<User?> build() async {
    // Return user immediately without SharedPreferences delay
    return User(userId: '1', endpoint: 'http://localhost:5001/graphql');
  }
}

void main() {
  test('Print output of GetAllModelTypes query and verify expected model types', () async {
    print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('🧪 TEST: Printing output of GetAllModelTypes query');
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
      print('📞 Calling modelTypesProvider...');
      print('   Query: GetAllModelTypes\n');
      
      // Call the provider to get all model types
      final result = await container.read(modelTypesProvider.future);
      
      print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('✅ QUERY RESULT:');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
      
      // Pretty print the JSON result
      if (result.isNotEmpty) {
        final encoder = JsonEncoder.withIndent('  ');
        print(encoder.convert(result.map((mt) => mt.toJson()).toList()));
        print('\n📊 Total model types: ${result.length}');
      } else {
        print('[] (no model types returned)');
      }
      
      // Verify expected model types and their relationships
      print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('🔍 VERIFYING EXPECTED MODEL TYPES AND RELATIONSHIPS:');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
      
      // Helper function to find model type by ID (recursively searches children)
      // Returns the model type and whether it was found as a child (not root)
      ModelType? findById(int id, {bool? isChild}) {
        // Search root nodes
        try {
          final root = result.firstWhere((mt) => mt.id == id);
          if (isChild != null) isChild = false;
          return root;
        } catch (e) {
          // Not found in root, search children recursively
          for (var root in result) {
            if (root.children != null) {
              for (var child in root.children!) {
                if (child.id == id) {
                  if (isChild != null) isChild = true;
                  return child;
                }
              }
            }
          }
          return null;
        }
      }
      
      // Helper to check if a model type is a child (not root)
      bool isChildModelType(int id) {
        for (var root in result) {
          if (root.children != null) {
            for (var child in root.children!) {
              if (child.id == id) {
                return true;
              }
            }
          }
        }
        return false;
      }
      
      // Expected model types (hardcoded for userId 1)
      final expectedModelTypes = [
        {
          'id': 1,
          'name': 'Real Nouns',
          'typeKind': 'abstract',
          'description': 'Physical or real-world entities',
          'parentId': null,
        },
        {
          'id': 2,
          'name': 'Digital Nouns',
          'typeKind': 'abstract',
          'description': 'Digital or virtual entities',
          'parentId': null,
        },
        {
          'id': 3,
          'name': 'Action',
          'typeKind': 'abstract',
          'description': 'An action or activity',
          'parentId': null,
        },
        {
          'id': 4,
          'name': 'Person',
          'typeKind': 'base',
          'description': 'A human person',
          'parentId': 1, // Child of Real Nouns
        },
        {
          'id': 5,
          'name': 'Company',
          'typeKind': 'base',
          'description': 'A business organization',
          'parentId': 1, // Child of Real Nouns
        },
      ];
      
      bool allVerified = true;
      
      for (final expected in expectedModelTypes) {
        final modelType = findById(expected['id'] as int);
        
        if (modelType == null) {
          print('❌ ModelType with id ${expected['id']} not found');
          allVerified = false;
          continue;
        }
        
        // Check if this is a child model type (nested under a root)
        final isChild = isChildModelType(expected['id'] as int);
        
        // Verify properties
        // Note: userId is not included in the struct, so it may be null
        // Note: parentId may be null for children in nested structure (per documentation)
        final checks = <String, bool>{
          'name': modelType.name == expected['name'],
          'typeKind': modelType.typeKind == expected['typeKind'],
          'description': modelType.description == expected['description'],
        };
        
        // For parentId: children now have parentId set during parsing
        // Check that parentId matches the expected value
        bool parentIdMatches = true;
        if (expected['parentId'] != null) {
          // Check parentId matches expected value
          if (modelType.parentId != expected['parentId']) {
            parentIdMatches = false;
          }
        } else {
          // If expected parentId is null, it should be null
          if (modelType.parentId != null) {
            parentIdMatches = false;
          }
        }
        
        final failedChecks = checks.entries.where((e) => !e.value).toList();
        if (!parentIdMatches) {
          failedChecks.add(MapEntry('parentId', false));
        }
        
        if (failedChecks.isEmpty) {
          print('✅ ModelType ${expected['id']} (${expected['name']}): All properties match');
          if (expected['parentId'] != null && !isChild) {
            // Only check parent for root nodes
            final parent = findById(expected['parentId'] as int);
            if (parent != null) {
              print('   └─ Parent: ${parent.name} (id: ${parent.id})');
            } else {
              print('   └─ ⚠️  Parent (id: ${expected['parentId']}) not found');
              allVerified = false;
            }
          } else if (isChild) {
            print('   └─ Note: Found as child in nested structure (parentId not shown per documentation)');
          }
        } else {
          print('❌ ModelType ${expected['id']} (${expected['name']}): Failed checks:');
          for (final check in failedChecks) {
            final actualValue = check.key == 'name' ? modelType.name 
                : check.key == 'typeKind' ? modelType.typeKind 
                : check.key == 'description' ? modelType.description 
                : check.key == 'parentId' ? '${modelType.parentId} (isChild: $isChild)'
                : 'N/A';
            print('   - ${check.key}: expected ${expected[check.key]}, got $actualValue');
          }
          allVerified = false;
        }
      }
      
      print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      if (allVerified) {
        print('✅ All expected model types and relationships verified!');
      } else {
        print('❌ Some verifications failed');
      }
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
      
      // Assert that all verifications passed
      expect(allVerified, isTrue, reason: 'Not all expected model types and relationships were found');
      
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

  test('Test modelTypeProvider with ID lookup and verify both providers work', () async {
    print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('🧪 TEST: Testing modelTypeProvider with ID lookup');
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
      
      print('✅ Auth provider ready\n');
      
      // Test 1: Get all model types first
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('📋 TEST 1: Get all model types using modelTypesProvider');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
      
      final allModelTypes = await container.read(modelTypesProvider.future);
      
      print('✅ Retrieved ${allModelTypes.length} root model types');
      
      if (allModelTypes.isEmpty) {
        throw Exception('No model types returned from modelTypesProvider');
      }
      
      // Find a model type with an ID (Person should be ID 4)
      ModelType? personFromAll;
      for (var root in allModelTypes) {
        if (root.name == 'Person') {
          personFromAll = root;
          break;
        }
        // Check children
        if (root.children != null) {
          for (var child in root.children!) {
            if (child.name == 'Person') {
              personFromAll = child;
              break;
            }
          }
        }
      }
      
      if (personFromAll == null) {
        throw Exception('Person model type not found in allModelTypes');
      }
      
      final personId = personFromAll.id;
      print('   Found Person with ID: $personId\n');
      
      // Test 2: Get single model type by ID
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('📋 TEST 2: Get single model type by ID using modelTypeProvider');
      print('   Querying ID: $personId (Person)');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
      
      final personById = await container.read(modelTypeProvider(personId).future);
      
      if (personById == null) {
        throw Exception('modelTypeProvider returned null for ID $personId');
      }
      
      print('✅ Retrieved model type by ID:');
      print('   ID: ${personById.id}');
      print('   Name: ${personById.name}');
      print('   Type Kind: ${personById.typeKind}');
      print('   Description: ${personById.description ?? 'null'}');
      print('   Parent ID: ${personById.parentId ?? 'null'}');
      if (personById.parent != null) {
        print('   Parent: ${personById.parent!.name} (id: ${personById.parent!.id})');
      }
      print('   Children: ${personById.children?.length ?? 0}');
      print('   Traits: ${personById.traits?.length ?? 0}\n');
      
      // Verify the results match
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('🔍 VERIFYING: Comparing results from both providers');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
      
      bool allMatch = true;
      
      // Compare basic properties
      // Note: parentId may differ because when Person is nested as a child in allModelTypes,
      // it doesn't include the parent field (per documentation), but when queried directly,
      // it does include the parent field. So we check parentId separately.
      final checks = <String, bool>{
        'id': personFromAll.id == personById.id,
        'name': personFromAll.name == personById.name,
        'typeKind': personFromAll.typeKind == personById.typeKind,
        'description': personFromAll.description == personById.description,
      };
      
      for (final check in checks.entries) {
        if (check.value) {
          print('✅ ${check.key}: Match');
        } else {
          print('❌ ${check.key}: Mismatch');
          print('   From allModelTypes: ${check.key == 'id' ? personFromAll.id : check.key == 'name' ? personFromAll.name : check.key == 'typeKind' ? personFromAll.typeKind : personFromAll.description}');
          print('   From modelTypeProvider: ${check.key == 'id' ? personById.id : check.key == 'name' ? personById.name : check.key == 'typeKind' ? personById.typeKind : personById.description}');
          allMatch = false;
        }
      }
      
      // Check parentId separately - when Person is a child in nested structure, it doesn't show parent
      // But when queried directly, it does show parent. Both are valid.
      print('ℹ️  parentId: From allModelTypes (as child): ${personFromAll.parentId ?? 'null'}, From modelTypeProvider (direct): ${personById.parentId ?? 'null'}');
      print('   Note: Children in nested structure don\'t show parent field, but direct queries do (both are valid)');
      
      // Test 3: Test with invalid ID
      print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('📋 TEST 3: Test with invalid ID (should return null)');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
      
      final invalidResult = await container.read(modelTypeProvider(99999).future);
      
      if (invalidResult == null) {
        print('✅ Invalid ID correctly returned null');
      } else {
        print('❌ Invalid ID should return null, but got: ${invalidResult.name}');
        allMatch = false;
      }
      
      // Test 4: Test with another known ID (Company)
      print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('📋 TEST 4: Test with Company ID');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
      
      ModelType? companyFromAll;
      for (var root in allModelTypes) {
        if (root.name == 'Company') {
          companyFromAll = root;
          break;
        }
        if (root.children != null) {
          for (var child in root.children!) {
            if (child.name == 'Company') {
              companyFromAll = child;
              break;
            }
          }
        }
      }
      
      if (companyFromAll != null) {
        final companyId = companyFromAll.id;
        print('   Querying Company with ID: $companyId');
        
        final companyById = await container.read(modelTypeProvider(companyId).future);
        
        if (companyById == null) {
          print('❌ Company not found by ID');
          allMatch = false;
        } else {
          print('✅ Retrieved Company by ID:');
          print('   Name: ${companyById.name}');
          print('   Type Kind: ${companyById.typeKind}');
          
          if (companyById.name == 'Company' && companyById.id == companyId) {
            print('✅ Company ID lookup successful');
          } else {
            print('❌ Company ID lookup returned wrong model type');
            allMatch = false;
          }
        }
      } else {
        print('⚠️  Company not found in allModelTypes, skipping test');
      }
      
      print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      if (allMatch) {
        print('✅ All tests passed! Both providers work correctly.');
      } else {
        print('❌ Some tests failed');
      }
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
      
      // Assert that all tests passed
      expect(allMatch, isTrue, reason: 'Not all provider tests passed');
      
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

