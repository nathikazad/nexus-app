import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'dart:convert';
import 'package:nexus_voice_assistant/data_providers/model_types_provider.dart';
import 'package:nexus_voice_assistant/models/requests/SetModelTypeRequest.dart';
import 'package:nexus_voice_assistant/models/ModelType.dart';
import 'package:nexus_voice_assistant/db.dart';

const String setKgqlModelTypesMutation = '''
mutation SetKgqlModelTypes(\$input: SetKgqlModelTypesInput!) {
  setKgqlModelTypes(input: \$input) {
    json
  }
}
''';

class ModelTypeFormController extends Notifier<ModelTypeFormState> {
  bool _hasLoaded = false;
  int? _modelTypeId;

  @override
  ModelTypeFormState build() {
    // Return initial state - modelTypeId will be set via initialize()
    return ModelTypeFormState();
  }

  void initialize(int? modelTypeId) {
    _modelTypeId = modelTypeId;
    if (modelTypeId != null) {
      state = state.copyWith(isLoading: true);
    }
  }

  int? get modelTypeId => _modelTypeId;

  void loadModelTypeData(ModelType data) {
    if (_hasLoaded) return;
    _hasLoaded = true;
    
    // Use attributes and relations directly from ModelType (already parsed into typed classes)
    final attributeDefinitions = data.attributes ?? <AttributeDefinition>[];
    final relationshipTypes = data.relations ?? <RelationshipType>[];
    
    // Update state with all loaded data
          state = state.copyWith(
            name: data.name,
            description: data.description ?? '',
            typeKind: data.typeKind ?? 'base',
            parentId: data.parentId,
            parentName: data.parentId != null && data.parent != null ? data.parent!.name : null,
      attributeDefinitions: attributeDefinitions,
      relationshipTypes: relationshipTypes,
      isLoading: false,
          );
  }

  void setName(String name) {
    state.nameController.text = name;
    state = state.copyWith();
  }

  void setDescription(String description) {
    state.descriptionController.text = description;
    state = state.copyWith();
  }

  void setTypeKind(String typeKind) {
    state = state.copyWith(typeKind: typeKind);
  }

  void setParent(int id, String name) {
    state = state.copyWith(parentId: id, parentName: name);
  }

  void clearParent() {
    state = state.copyWith(parentId: null, parentName: null);
  }

  void addAttributeDefinition(AttributeDefinition attribute) {
    state = state.copyWith(
      attributeDefinitions: [...state.attributeDefinitions, attribute],
    );
  }

  void updateAttributeDefinition(int index, AttributeDefinition attribute) {
    final updated = List<AttributeDefinition>.from(state.attributeDefinitions);
    updated[index] = attribute;
    state = state.copyWith(attributeDefinitions: updated);
  }

  void removeAttributeDefinition(int index) {
    final updated = List<AttributeDefinition>.from(state.attributeDefinitions);
    final attrToRemove = updated[index];
    
    // If it has an ID, mark it for deletion instead of removing it
    if (attrToRemove.id != null) {
      updated[index] = AttributeDefinition(
        id: attrToRemove.id,
        delete: true,
      );
      state = state.copyWith(attributeDefinitions: updated);
    } else {
      // If it's a new attribute (no ID), just remove it
    updated.removeAt(index);
    state = state.copyWith(attributeDefinitions: updated);
    }
  }

  void addRelationship(RelationshipType relationship) {
    state = state.copyWith(
      relationshipTypes: [...state.relationshipTypes, relationship],
    );
  }

  void updateRelationship(int index, RelationshipType relationship) {
    final updated = List<RelationshipType>.from(state.relationshipTypes);
    updated[index] = relationship;
    state = state.copyWith(relationshipTypes: updated);
  }

  void removeRelationship(int index) {
    final updated = List<RelationshipType>.from(state.relationshipTypes);
    final relToRemove = updated[index];
    
    // If it has an ID, mark it for deletion instead of removing it
    if (relToRemove.id != null) {
      updated[index] = RelationshipType(
        id: relToRemove.id,
        delete: true,
      );
      state = state.copyWith(relationshipTypes: updated);
    } else {
      // If it's a new relationship (no ID), just remove it
    updated.removeAt(index);
    state = state.copyWith(relationshipTypes: updated);
    }
  }

  Future<void> save(BuildContext context) async {
    if (!state.formKey.currentState!.validate()) {
      return;
    }

    final client = ref.read(graphqlClientProvider);
    final isEditing = modelTypeId != null;

    try {
      // Build the request using SetModelTypeRequest
      final request = SetModelTypeRequest(
        id: isEditing ? modelTypeId : null,
        name: state.nameController.text,
        typeKind: state.typeKind,
        description: state.descriptionController.text.isEmpty 
            ? null 
            : state.descriptionController.text,
        parent: state.parentId != null 
            ? ParentLink.fromId(state.parentId!) 
            : null,
        attributeDefinitions: state.attributeDefinitions.isNotEmpty
            ? state.attributeDefinitions
            : null,
        relationshipTypes: state.relationshipTypes.isNotEmpty
            ? state.relationshipTypes
            : null,
      );

      // Convert request to JSON
      final requestJson = request.toJson();

      // Call set_kgql_model_types mutation
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
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${result.exception}')),
          );
        }
        return;
      }

      // Extract the created/updated model type ID
      final responseData = result.data?['setKgqlModelTypes'] as Map<String, dynamic>?;
      if (responseData == null) {
        throw Exception('No data returned from setKgqlModelTypes mutation');
      }

      final jsonResult = responseData['json'];
      final jsonData = jsonResult is String 
          ? json.decode(jsonResult) as Map<String, dynamic>
          : jsonResult as Map<String, dynamic>;

      final savedModelTypeId = jsonData['id'] as int?;
      if (savedModelTypeId == null) {
        throw Exception('No ID returned from setKgqlModelTypes mutation');
      }

      // Invalidate providers to refresh data
      ref.invalidate(modelTypesProvider);
      if (this.modelTypeId != null) {
        ref.invalidate(modelTypeProvider(this.modelTypeId!));
      }

      if (context.mounted) {
        Navigator.pop(context, true); // Return true to indicate success
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEditing ? 'Model type updated' : 'Model type created')),
        );
      }
    } catch (e, stackTrace) {
      print('❌ Exception in model_type_form_controller.save:');
      print('Error: $e');
      print('Stack trace: $stackTrace');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void dispose() {
    state.nameController.dispose();
    state.descriptionController.dispose();
  }
}

class ModelTypeFormState {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController descriptionController;
  final String typeKind;
  final int? parentId;
  final String? parentName;
  final List<AttributeDefinition> attributeDefinitions;
  final List<RelationshipType> relationshipTypes;
  final bool isLoading;

  ModelTypeFormState({
    GlobalKey<FormState>? formKey,
    TextEditingController? nameController,
    TextEditingController? descriptionController,
    String? typeKind,
    int? parentId,
    String? parentName,
    List<AttributeDefinition>? attributeDefinitions,
    List<RelationshipType>? relationshipTypes,
    bool isLoading = false,
  })  : formKey = formKey ?? GlobalKey<FormState>(),
        nameController = nameController ?? TextEditingController(),
        descriptionController = descriptionController ?? TextEditingController(),
        typeKind = typeKind ?? 'base',
        parentId = parentId,
        parentName = parentName,
        attributeDefinitions = attributeDefinitions ?? [],
        relationshipTypes = relationshipTypes ?? [],
        isLoading = isLoading;

  ModelTypeFormState copyWith({
    GlobalKey<FormState>? formKey,
    TextEditingController? nameController,
    TextEditingController? descriptionController,
    String? name,
    String? description,
    String? typeKind,
    int? parentId,
    String? parentName,
    List<AttributeDefinition>? attributeDefinitions,
    List<RelationshipType>? relationshipTypes,
    bool? isLoading,
  }) {
    final newNameController = nameController ?? this.nameController;
    final newDescriptionController = descriptionController ?? this.descriptionController;
    
    if (name != null) {
      newNameController.text = name;
    }
    if (description != null) {
      newDescriptionController.text = description;
    }

    return ModelTypeFormState(
      formKey: formKey ?? this.formKey,
      nameController: newNameController,
      descriptionController: newDescriptionController,
      typeKind: typeKind ?? this.typeKind,
      parentId: parentId ?? this.parentId,
      parentName: parentName ?? this.parentName,
      attributeDefinitions: attributeDefinitions ?? this.attributeDefinitions,
      relationshipTypes: relationshipTypes ?? this.relationshipTypes,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

final modelTypeFormControllerProvider = NotifierProvider.family<ModelTypeFormController, ModelTypeFormState, int?>(
  (int? modelTypeId) {
    final controller = ModelTypeFormController();
    controller.initialize(modelTypeId);
    return controller;
  },
);

