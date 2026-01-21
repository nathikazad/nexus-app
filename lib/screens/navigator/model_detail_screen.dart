import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nexus_voice_assistant/data_providers/models_provider.dart';
import 'package:nexus_voice_assistant/models/Model.dart';
import 'package:nexus_voice_assistant/widgets/loading_indicator.dart';
import 'package:nexus_voice_assistant/widgets/error_widget.dart';

class ModelDetailScreen extends ConsumerWidget {
  final int modelId;

  const ModelDetailScreen({
    super.key,
    required this.modelId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modelAsync = ref.watch(modelProvider(modelId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Model Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              modelAsync.whenData((model) {
                if (model != null) {
                  context.push('/model-form?modelId=$modelId&modelTypeId=${model.modelTypeId}');
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete Model'),
                  content: const Text('Are you sure you want to delete this model?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );

              if (confirmed == true) {
                // TODO: Implement delete mutation
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Delete functionality not yet implemented')),
                );
              }
            },
          ),
        ],
      ),
      body: modelAsync.when(
        data: (model) {
          if (model == null) {
            return const Center(child: Text('Model not found'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  model.name,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),
                if (model.description != null && model.description!.isNotEmpty)
                  Text(
                    model.description!,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                const SizedBox(height: 24),
                if (model.attributesList != null && model.attributesList!.isNotEmpty)
                  _buildSection(
                    context,
                    'Attributes',
                    _buildAttributesList(model.attributesList!),
                  )
                else if (model.attributes != null && model.attributes!.isNotEmpty)
                  _buildSection(
                    context,
                    'Attributes',
                    _buildAttributes(model.attributes!),
                  ),
                if (model.relationsByModelType.isNotEmpty)
                  _buildSection(
                    context,
                    'Relations',
                    _buildRelationsByRelationName(context, model.relationsByModelType),
                  )
                else if (model.relations != null && model.relations!.isNotEmpty)
                  _buildSection(
                      context,
                    'Relations',
                    _buildRelations(context, model.relations!),
                  ),
              ],
            ),
          );
        },
        loading: () => const LoadingIndicator(),
        error: (error, stack) => ErrorDisplay(
          message: error.toString(),
          onRetry: () {
            ref.invalidate(modelProvider(modelId));
          },
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        content,
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildAttributes(Map<String, dynamic> attributes) {
    if (attributes.isEmpty) {
      return const Text('No attributes');
    }

    return Column(
      children: attributes.entries.map((entry) {
        return Card(
          child: ListTile(
            title: Text(entry.key),
            subtitle: Text(_formatAttributeValue(entry.value)),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAttributesList(List<ModelAttribute> attributes) {
    if (attributes.isEmpty) {
      return const Text('No attributes');
    }

    return Column(
      children: attributes.map((attr) {
        return Card(
          child: ListTile(
            title: Text(attr.key),
            subtitle: Text(_formatAttributeValue(attr.value)),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRelationsByRelationName(BuildContext context, Map<String, List<Relation>> relationsByModelType) {
    if (relationsByModelType.isEmpty) {
      return const Text('No relations');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: relationsByModelType.entries.map((entry) {
        final modelTypeName = entry.key;
        final relationsForType = entry.value;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Text(
                modelTypeName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ...relationsForType.map((relation) {
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(relation.name ?? 'Untitled'),
                  trailing: const Icon(Icons.arrow_forward),
                  onTap: () {
                    context.push('/model-detail/${relation.modelId}');
                  },
                ),
              );
            }).toList(),
            const SizedBox(height: 8),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildRelations(BuildContext context, Map<String, List<Model>> relations) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: relations.entries.map((entry) {
        final modelTypeName = entry.key;
        final relatedModels = entry.value;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Text(
                modelTypeName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ...relatedModels.map((relatedModel) {
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(relatedModel.name),
                  subtitle: relatedModel.description != null && relatedModel.description!.isNotEmpty
                      ? Text(relatedModel.description!)
                      : null,
                  trailing: const Icon(Icons.arrow_forward),
                  onTap: () {
                    context.push('/model-detail/${relatedModel.id}');
                  },
                ),
              );
            }).toList(),
            const SizedBox(height: 8),
          ],
        );
      }).toList(),
    );
  }

  String _formatAttributeValue(dynamic value) {
    if (value == null) return 'No value';
    return value.toString();
  }
}

