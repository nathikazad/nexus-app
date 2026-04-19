import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nexus_voice_assistant/data/schema/kgql_model_type_repository.dart';
import 'package:nx_db/riverpod.dart' show modelTypeProvider, modelTypesProvider;
import 'package:nexus_voice_assistant/domain/schema/attribute_definition_draft.dart';
import 'package:nexus_voice_assistant/domain/schema/model_type_form_state.dart';
import 'package:nexus_voice_assistant/domain/schema/relation_definition_draft.dart';
import 'package:nexus_voice_assistant/domain/schema/schema_model_type.dart';

class ModelTypeFormController extends Notifier<ModelTypeFormState> {
  bool _hasLoaded = false;
  int? _modelTypeId;

  set modelTypeId(int? value) {
    _modelTypeId = value;
  }

  @override
  ModelTypeFormState build() {
    return ModelTypeFormState(
      isLoading: _modelTypeId != null,
    );
  }

  void initialize(int? modelTypeId) {
    _modelTypeId = modelTypeId;
    if (modelTypeId != null) {
      state = state.copyWith(isLoading: true);
    }
  }

  int? get modelTypeId => _modelTypeId;

  void loadModelTypeData(SchemaModelType data) {
    if (_hasLoaded) return;
    _hasLoaded = true;

    final f = ModelTypeFormFields.fromSchemaModelType(data);
    state.nameController.text = f.name;
    state.descriptionController.text = f.description;
    state = state.copyWith(
      typeKind: f.typeKind,
      parentId: f.parentId,
      parentName: f.parentName,
      attributeDefinitions: f.attributeDefinitions,
      relationshipTypes: f.relationshipTypes,
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

  void addAttributeDefinition(AttributeDefinitionDraft attribute) {
    state = state.copyWith(
      attributeDefinitions: [...state.attributeDefinitions, attribute],
    );
  }

  void updateAttributeDefinition(int index, AttributeDefinitionDraft attribute) {
    final updated = List<AttributeDefinitionDraft>.from(state.attributeDefinitions);
    updated[index] = attribute;
    state = state.copyWith(attributeDefinitions: updated);
  }

  void removeAttributeDefinition(int index) {
    final updated = List<AttributeDefinitionDraft>.from(state.attributeDefinitions);
    final attrToRemove = updated[index];

    if (attrToRemove.id != null) {
      updated[index] = AttributeDefinitionDraft(
        id: attrToRemove.id,
        delete: true,
      );
      state = state.copyWith(attributeDefinitions: updated);
    } else {
      updated.removeAt(index);
      state = state.copyWith(attributeDefinitions: updated);
    }
  }

  void addRelationship(RelationDefinitionDraft relationship) {
    state = state.copyWith(
      relationshipTypes: [...state.relationshipTypes, relationship],
    );
  }

  void updateRelationship(int index, RelationDefinitionDraft relationship) {
    final updated = List<RelationDefinitionDraft>.from(state.relationshipTypes);
    updated[index] = relationship;
    state = state.copyWith(relationshipTypes: updated);
  }

  void removeRelationship(int index) {
    final updated = List<RelationDefinitionDraft>.from(state.relationshipTypes);
    final relToRemove = updated[index];

    if (relToRemove.id != null) {
      updated[index] = RelationDefinitionDraft(
        id: relToRemove.id,
        delete: true,
      );
      state = state.copyWith(relationshipTypes: updated);
    } else {
      updated.removeAt(index);
      state = state.copyWith(relationshipTypes: updated);
    }
  }

  Future<void> save(BuildContext context) async {
    if (!state.formKey.currentState!.validate()) {
      return;
    }

    final repo = ref.read(modelTypeWriteRepositoryProvider);
    final isEditing = modelTypeId != null;

    try {
      await repo.setModelType(
        id: isEditing ? modelTypeId : null,
        name: state.nameController.text,
        typeKind: state.typeKind,
        description: state.descriptionController.text.isEmpty
            ? null
            : state.descriptionController.text,
        parentId: state.parentId,
        attributeDefinitions: state.attributeDefinitions,
        relationshipTypes: state.relationshipTypes,
      );

      ref.invalidate(modelTypesProvider);
      if (modelTypeId != null) {
        ref.invalidate(modelTypeProvider(modelTypeId!));
      }

      if (context.mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEditing ? 'Model type updated' : 'Model type created',
            ),
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('Exception in ModelTypeFormController.save: $e\n$stackTrace');
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
  final List<AttributeDefinitionDraft> attributeDefinitions;
  final List<RelationDefinitionDraft> relationshipTypes;
  final bool isLoading;

  ModelTypeFormState({
    GlobalKey<FormState>? formKey,
    TextEditingController? nameController,
    TextEditingController? descriptionController,
    String? typeKind,
    int? parentId,
    String? parentName,
    List<AttributeDefinitionDraft>? attributeDefinitions,
    List<RelationDefinitionDraft>? relationshipTypes,
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
    List<AttributeDefinitionDraft>? attributeDefinitions,
    List<RelationDefinitionDraft>? relationshipTypes,
    bool? isLoading,
  }) {
    final newNameController = nameController ?? this.nameController;
    final newDescriptionController =
        descriptionController ?? this.descriptionController;

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

final modelTypeFormControllerProvider = NotifierProvider.family<
    ModelTypeFormController,
    ModelTypeFormState,
    int?>((int? modelTypeId) {
  final controller = ModelTypeFormController();
  controller.modelTypeId = modelTypeId;
  return controller;
});
