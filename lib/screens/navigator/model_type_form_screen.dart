import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nexus_voice_assistant/data_providers/model_types_provider.dart';
import 'model_type_form_controller.dart';
import 'widgets/model_type_basic_fields.dart';
import 'widgets/attribute_definitions_section.dart';
import 'widgets/relationships_section.dart';


class ModelTypeFormScreen extends ConsumerStatefulWidget {
  final int? modelTypeId;

  const ModelTypeFormScreen({
    super.key,
    this.modelTypeId,
  });

  @override
  ConsumerState<ModelTypeFormScreen> createState() => _ModelTypeFormScreenState();
}

class _ModelTypeFormScreenState extends ConsumerState<ModelTypeFormScreen> {
  @override
  Widget build(BuildContext context) {
    final controllerNotifier = ref.watch(modelTypeFormControllerProvider(widget.modelTypeId).notifier);
    final controllerState = ref.watch(modelTypeFormControllerProvider(widget.modelTypeId));
    
    // Initialize controller with modelTypeId
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (controllerNotifier.modelTypeId != widget.modelTypeId) {
        controllerNotifier.initialize(widget.modelTypeId);
      }
    });
    
    // Watch the provider to trigger loading when data is ready
    if (widget.modelTypeId != null) {
      final modelTypeAsync = ref.watch(modelTypeProvider(widget.modelTypeId!));
      
      // Trigger loading when provider has data
      modelTypeAsync.when(
        data: (data) {
          if (data != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              controllerNotifier.loadModelTypeData(data);
            });
          }
        },
        loading: () {},
        error: (error, stack) {
          print('❌ Error loading model type: $error');
        },
      );
    }
    
    // Show loading indicator while data is being fetched
    if (widget.modelTypeId != null && controllerState.isLoading) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          title: const Text('Edit Model Type'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(widget.modelTypeId == null ? 'Create Model Type' : 'Edit Model Type'),
      ),
      body: Form(
        key: controllerState.formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ModelTypeBasicFields(
              nameController: controllerState.nameController,
              descriptionController: controllerState.descriptionController,
              typeKind: controllerState.typeKind,
              onTypeKindChanged: (value) {
                controllerNotifier.setTypeKind(value);
              },
              parentId: controllerState.parentId,
              parentName: controllerState.parentName,
              onClearParent: () {
                controllerNotifier.clearParent();
              },
              onSelectParent: () async {
                              final result = await context.push('/model-type-selector');
                              if (result != null && result is Map<String, dynamic>) {
                  controllerNotifier.setParent(
                    result['id'] as int,
                    result['name'] as String,
                  );
                }
              },
            ),
            const SizedBox(height: 16),
            AttributeDefinitionsSection(
              attributeDefinitions: controllerState.attributeDefinitions,
              onAdd: (attribute) {
                controllerNotifier.addAttributeDefinition(attribute);
              },
              onUpdate: (index, attribute) {
                controllerNotifier.updateAttributeDefinition(index, attribute);
              },
              onDelete: (index) {
                controllerNotifier.removeAttributeDefinition(index);
              },
            ),
            const SizedBox(height: 16),
            RelationshipsSection(
              relationshipTypes: controllerState.relationshipTypes,
              onAdd: (relationship) {
                controllerNotifier.addRelationship(relationship);
              },
              onUpdate: (index, relationship) {
                controllerNotifier.updateRelationship(index, relationship);
                                      },
              onDelete: (index) {
                controllerNotifier.removeRelationship(index);
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => controllerNotifier.save(context),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
