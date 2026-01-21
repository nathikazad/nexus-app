import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nexus_voice_assistant/data_providers/models_provider.dart';
import 'package:nexus_voice_assistant/data_providers/model_types_provider.dart';
import 'package:nexus_voice_assistant/widgets/loading_indicator.dart';
import 'package:nexus_voice_assistant/widgets/error_widget.dart';
import 'package:nexus_voice_assistant/widgets/model_row.dart';

class ModelsListScreen extends ConsumerWidget {
  final int modelTypeId;

  const ModelsListScreen({
    super.key,
    required this.modelTypeId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modelsAsync = ref.watch(modelsProvider(modelTypeId));
    final modelTypeAsync = ref.watch(modelTypeProvider(modelTypeId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: modelTypeAsync.when(
          data: (data) {
            if (data != null) {
              return Text(data.name);
            }
            return const Text('Models');
          },
          loading: () => const Text('Models'),
          error: (_, __) => const Text('Models'),
        ),
        elevation: 0,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return modelsAsync.when(
            data: (models) {
              if (models.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.inbox, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('No models found'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          context.push('/model-form?modelTypeId=$modelTypeId');
                        },
                        child: const Text('Create Model'),
                      ),
                    ],
                  ),
                );
              }

              if (constraints.maxWidth < 600) {
                // Mobile: ListView
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(modelsProvider(modelTypeId));
                  },
                  child: ListView.builder(
                    itemCount: models.length,
                    itemBuilder: (context, index) {
                      final model = models[index];
                      return ModelRow(
                        model: model,
                        onTap: () {
                          context.push('/model-detail/${model.id}');
                        },
                      );
                    },
                  ),
                );
              } else {
                // Desktop: DataTable
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(modelsProvider(modelTypeId));
                  },
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Name')),
                        DataColumn(label: Text('Description')),
                        DataColumn(label: Text('Created')),
                        DataColumn(label: Text('Updated')),
                      ],
                      rows: models.map((model) {
                        return DataRow(
                          cells: [
                            DataCell(Text(model.name)),
                            DataCell(
                              Text(
                                (model.description ?? '').length > 50
                                    ? '${model.description!.substring(0, 50)}...'
                                    : (model.description ?? ''),
                              ),
                            ),
                            DataCell(Text(model.createdAt ?? '')),
                            DataCell(Text(model.updatedAt ?? '')),
                          ],
                          onSelectChanged: (selected) {
                            if (selected == true) {
                              context.push('/model-detail/${model.id}');
                            }
                          },
                        );
                      }).toList(),
                    ),
                  ),
                );
              }
            },
            loading: () => const LoadingIndicator(),
            error: (error, stack) => ErrorDisplay(
              message: error.toString(),
              onRetry: () {
                ref.invalidate(modelsProvider(modelTypeId));
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.push('/model-form?modelTypeId=$modelTypeId');
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

