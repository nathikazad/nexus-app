import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nexus_voice_assistant/data_providers/model_types_provider.dart';
import 'package:nexus_voice_assistant/models/ModelType.dart';
import 'package:nexus_voice_assistant/auth.dart';
import 'package:nexus_voice_assistant/widgets/loading_indicator.dart';
import 'package:nexus_voice_assistant/widgets/error_widget.dart';
import 'package:nexus_voice_assistant/screens/navigator/widgets/model_type_row.dart';
import 'package:nexus_voice_assistant/widgets/expanding_fab_menu.dart';

class NavigatorHomeScreen extends ConsumerStatefulWidget {
  const NavigatorHomeScreen({super.key});

  @override
  ConsumerState<NavigatorHomeScreen> createState() => _NavigatorHomeScreenState();
}

class _NavigatorHomeScreenState extends ConsumerState<NavigatorHomeScreen> {
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

  @override
  Widget build(BuildContext context) {
    final modelTypesAsync = ref.watch(modelTypesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Model Types'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
            },
            tooltip: 'Logout',
          ),
        ],
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
                        onTap: () {
                          // Navigate to models list for base types, settings for others
                          if (modelType.typeKind == 'base') {
                            context.push('/models/${modelType.id}');
                          } else {
                            context.push('/model-type-settings/${modelType.id}');
                          }
                        },
                          onSettingsTap: () async {
                            final result = await context.push('/model-type-form?modelTypeId=${modelType.id}');
                            // If model type was updated successfully, refetch model types
                            if (result == true) {
                              ref.invalidate(modelTypesProvider);
                            }
                          },
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
      floatingActionButton: ExpandingFabMenu(
        onModelTypeTap: () async {
          final result = await context.push('/model-type-form');
          // If model type was created/updated successfully, refetch model types
          if (result == true) {
            ref.invalidate(modelTypesProvider);
          }
        },
        onModelTap: () {
          // TODO: Navigate to model form when route is available
          // context.push('/model-form');
        },
      ),
    );
  }
}

