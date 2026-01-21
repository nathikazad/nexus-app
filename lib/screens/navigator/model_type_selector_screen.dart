import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nexus_voice_assistant/data_providers/model_types_provider.dart';
import 'package:nexus_voice_assistant/models/ModelType.dart';
import 'package:nexus_voice_assistant/widgets/loading_indicator.dart';
import 'package:nexus_voice_assistant/widgets/error_widget.dart';
import 'widgets/model_type_row.dart';

class ModelTypeSelectorScreen extends ConsumerStatefulWidget {
  const ModelTypeSelectorScreen({super.key});

  @override
  ConsumerState<ModelTypeSelectorScreen> createState() => _ModelTypeSelectorScreenState();
}

class _ModelTypeSelectorScreenState extends ConsumerState<ModelTypeSelectorScreen> {
  // Track which model types are expanded (by ID)
  final Set<int> _expandedIds = {};

  void _toggleExpand(int modelTypeId) {
    setState(() {
      if (_expandedIds.contains(modelTypeId)) {
        _expandedIds.remove(modelTypeId);
      } else {
        _expandedIds.add(modelTypeId);
      }
    });
  }

  void _selectModelType(ModelType modelType) {
    // Return the selected model type to the previous screen
    context.pop({
      'id': modelType.id,
      'name': modelType.name,
    });
  }

  @override
  Widget build(BuildContext context) {
    final modelTypesAsync = ref.watch(modelTypesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Model Type'),
        elevation: 0,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return modelTypesAsync.when(
            data: (modelTypes) {
              if (modelTypes.isEmpty) {
                return const Center(
                  child: Text('No model types found'),
                );
              }

              // Helper function to build list items recursively
              List<Widget> buildModelTypeItems(List<ModelType> types, {int indentLevel = 0}) {
                final items = <Widget>[];
                for (var modelType in types) {
                  final hasChildren = modelType.children != null && modelType.children!.isNotEmpty;
                  final isExpanded = _expandedIds.contains(modelType.id);
                  
                  // Add the model type itself
                  items.add(
                    Padding(
                      padding: EdgeInsets.only(left: indentLevel * 32.0),
                      child: ModelTypeRow(
                        modelType: modelType,
                        showExpandButton: hasChildren,
                        isExpanded: isExpanded,
                        onExpandTap: hasChildren ? () => _toggleExpand(modelType.id) : null,
                        onTap: () => _selectModelType(modelType),
                        onSettingsTap: () {
                          // No settings in selector screen - not used
                        },
                        showSettingsButton: false,
                      ),
                    ),
                  );
                  
                  // Add children recursively with increased indent (only if expanded)
                  if (hasChildren && isExpanded) {
                    items.addAll(buildModelTypeItems(modelType.children!, indentLevel: indentLevel + 1));
                  }
                }
                return items;
              }

              // Build all items recursively
              final allItems = buildModelTypeItems(modelTypes);

              // Simple ListView for all screen sizes
              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(modelTypesProvider);
                },
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: allItems,
                ),
              );
            },
            loading: () => const LoadingIndicator(),
            error: (error, stack) => ErrorDisplay(
              message: error.toString(),
              onRetry: () {
                ref.invalidate(modelTypesProvider);
              },
            ),
          );
        },
      ),
    );
  }
}

