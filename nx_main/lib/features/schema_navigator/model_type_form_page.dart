import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nexus_voice_assistant/data/providers.dart';
import 'package:nexus_voice_assistant/features/schema_navigator/model_type_form_view_model.dart';
import 'package:nexus_voice_assistant/features/schema_navigator/widgets/attribute_definitions_section.dart';
import 'package:nexus_voice_assistant/features/schema_navigator/widgets/model_type_basic_fields.dart';
import 'package:nexus_voice_assistant/features/schema_navigator/widgets/relationships_section.dart';

class ModelTypeFormPage extends ConsumerStatefulWidget {
  final int? modelTypeId;

  const ModelTypeFormPage({
    super.key,
    this.modelTypeId,
  });

  @override
  ConsumerState<ModelTypeFormPage> createState() => _ModelTypeFormPageState();
}

class _ModelTypeFormPageState extends ConsumerState<ModelTypeFormPage> {
  @override
  Widget build(BuildContext context) {
    final controllerNotifier =
        ref.watch(modelTypeFormControllerProvider(widget.modelTypeId).notifier);
    final controllerState =
        ref.watch(modelTypeFormControllerProvider(widget.modelTypeId));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (controllerNotifier.modelTypeId != widget.modelTypeId) {
        controllerNotifier.initialize(widget.modelTypeId);
      }
    });

    if (widget.modelTypeId != null) {
      final modelTypeAsync =
          ref.watch(schemaModelTypeProvider(widget.modelTypeId!));

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
          debugPrint('Error loading model type: $error');
        },
      );
    }

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
        title: Text(widget.modelTypeId == null
            ? 'Create Model Type'
            : 'Edit Model Type'),
      ),
      body: Form(
        key: controllerState.formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ModelTypeBasicFields(
              nameController: controllerState.nameController,
              descriptionController: controllerState.descriptionController,
              agentInstructionsController:
                  controllerState.agentInstructionsController,
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
