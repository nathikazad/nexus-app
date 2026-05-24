import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nexus_voice_assistant/core/widgets/error_widget.dart';
import 'package:nexus_voice_assistant/core/widgets/loading_indicator.dart';
import 'package:nexus_voice_assistant/data/providers.dart';
import 'package:nexus_voice_assistant/domain/schema/schema_model.dart';
import 'package:nexus_voice_assistant/domain/schema/schema_model_attribute.dart';
import 'package:nexus_voice_assistant/domain/schema/schema_relation.dart';
import 'package:nx_db/riverpod.dart' show modelProvider;

class ModelDetailPage extends ConsumerWidget {
  const ModelDetailPage({
    super.key,
    required this.modelId,
  });

  final int modelId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modelAsync = ref.watch(schemaModelProvider(modelId));
    final typeNames = ref.watch(schemaModelTypeIdToNameProvider);

    return Scaffold(
      backgroundColor: _ModelUi.gray50,
      appBar: AppBar(
        title: const Text('Model'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: _ModelUi.gray200),
        ),
      ),
      body: modelAsync.when(
        data: (model) {
          if (model == null) {
            return const Center(child: Text('Model not found'));
          }
          final modelTypeName = model.modelType?.name ??
              typeNames[model.modelTypeId] ??
              'Model type ${model.modelTypeId}';

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _ModelHeader(model: model, modelTypeName: modelTypeName),
              _Section(
                title: 'Model Type',
                child: _ModelTypeLink(
                  modelTypeId: model.modelTypeId,
                  modelTypeName: modelTypeName,
                  description: model.modelType?.description,
                ),
              ),
              _Section(
                title: 'Attributes',
                child: _AttributesGrid(
                  coreFields: {
                    'name': model.name,
                    'description': model.description,
                  },
                  attributes: model.attributesList,
                  fallback: model.attributes,
                ),
              ),
              _Section(
                title: 'Relations',
                child:
                    _RelationsList(relations: model.relationsList ?? const []),
              ),
              _Section(
                title: 'Tags',
                child: _TagsPanel(tags: model.tags ?? const {}),
              ),
            ],
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
}

class _ModelHeader extends StatelessWidget {
  const _ModelHeader({required this.model, required this.modelTypeName});

  final SchemaModel model;
  final String modelTypeName;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _ModelUi.orange.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.data_object_rounded,
                  color: _ModelUi.orange,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      model.name.isEmpty ? 'Model #${model.id}' : model.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: _ModelUi.gray950,
                            fontWeight: FontWeight.w800,
                            height: 1.12,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _Chip(text: modelTypeName, color: _ModelUi.orange),
                        _Chip(text: '#${model.id}', color: _ModelUi.gray600),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if ((model.description ?? '').isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              model.description!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: _ModelUi.gray700,
                    height: 1.45,
                  ),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if ((model.createdAt ?? '').isNotEmpty)
                _Meta(text: 'Created ${model.createdAt}'),
              if ((model.updatedAt ?? '').isNotEmpty)
                _Meta(text: 'Updated ${model.updatedAt}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModelTypeLink extends StatelessWidget {
  const _ModelTypeLink({
    required this.modelTypeId,
    required this.modelTypeName,
    required this.description,
  });

  final int modelTypeId;
  final String modelTypeName;
  final String? description;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => context.push('/model-type/$modelTypeId'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: _ModelUi.orange.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.schema_rounded,
                color: _ModelUi.orange,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    modelTypeName,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: _ModelUi.gray950,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  if ((description ?? '').isNotEmpty)
                    Text(
                      description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: _ModelUi.gray600,
                            height: 1.35,
                          ),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: _ModelUi.gray500),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 8),
            child: Text(
              title.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: _ModelUi.gray500,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                  ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: _panelDecoration(),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _AttributesGrid extends StatelessWidget {
  const _AttributesGrid({
    required this.coreFields,
    required this.attributes,
    required this.fallback,
  });

  final Map<String, dynamic> coreFields;
  final List<SchemaModelAttribute>? attributes;
  final Map<String, dynamic>? fallback;

  @override
  Widget build(BuildContext context) {
    final seen = <String>{};
    final entries = <MapEntry<String, dynamic>>[
      for (final entry in coreFields.entries)
        if (seen.add(entry.key)) entry,
      if (attributes != null)
        for (final attr in attributes!)
          if (seen.add(attr.key)) MapEntry(attr.key, attr.value),
      if ((attributes == null || attributes!.isEmpty) && fallback != null)
        for (final entry in fallback!.entries)
          if (seen.add(entry.key)) entry,
    ];
    if (entries.isEmpty) return const _EmptyState(text: 'No attributes');

    return Column(
      children: [
        for (final entry in entries)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _ModelUi.gray50,
              border: Border.all(color: _ModelUi.gray200),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 120,
                  child: Text(
                    entry.key,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: _ModelUi.gray700,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                Expanded(
                  child: SelectableText(
                    _formatValue(entry.value),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: _ModelUi.gray700,
                          height: 1.35,
                        ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _RelationsList extends StatelessWidget {
  const _RelationsList({required this.relations});

  final List<SchemaRelation> relations;

  @override
  Widget build(BuildContext context) {
    if (relations.isEmpty) return const _EmptyState(text: 'No relations');
    final grouped = <String, List<SchemaRelation>>{};
    for (final relation in relations) {
      grouped.putIfAbsent(relation.modelType, () => []).add(relation);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final group in grouped.entries) ...[
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Text(
              group.key,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: _ModelUi.gray950,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          for (final relation in group.value) _RelationTile(relation: relation),
        ],
      ],
    );
  }
}

class _RelationTile extends StatelessWidget {
  const _RelationTile({required this.relation});

  final SchemaRelation relation;

  @override
  Widget build(BuildContext context) {
    final attrs = relation.relationAttributes ?? const <String, dynamic>{};
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _ModelUi.gray200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => context.push('/model-detail/${relation.modelId}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      relation.name?.isNotEmpty == true
                          ? relation.name!
                          : '${relation.modelType} #${relation.modelId}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: _ModelUi.gray950,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      color: _ModelUi.gray500),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _Meta(text: '${relation.modelType} #${relation.modelId}'),
                  if ((relation.relation ?? '').isNotEmpty)
                    _Meta(text: relation.relation!),
                  _Meta(text: 'relation #${relation.relationId}'),
                ],
              ),
              if ((relation.description ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  relation.description!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _ModelUi.gray600,
                        height: 1.35,
                      ),
                ),
              ],
              if (attrs.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final entry in attrs.entries)
                      _Chip(
                        text: '${entry.key}: ${_formatValue(entry.value)}',
                        color: _ModelUi.blue,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TagsPanel extends StatelessWidget {
  const _TagsPanel({required this.tags});

  final Map<String, List<String>> tags;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const _EmptyState(text: 'No tags');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final system in tags.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  system.key,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: _ModelUi.gray700,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final tag in system.value)
                      _Chip(text: tag, color: _ModelUi.green),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: _ModelUi.gray500,
            fontWeight: FontWeight.w600,
          ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.24)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _ModelUi.gray50,
        border: Border.all(color: _ModelUi.gray200),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: _ModelUi.gray600,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}

BoxDecoration _panelDecoration() {
  return BoxDecoration(
    color: Colors.white,
    border: Border.all(color: _ModelUi.gray200),
    borderRadius: BorderRadius.circular(10),
    boxShadow: const [
      BoxShadow(
        color: Color(0x06000000),
        blurRadius: 10,
        offset: Offset(0, 3),
      ),
    ],
  );
}

String _formatValue(dynamic value) {
  if (value == null) return '-';
  if (value is String) return value;
  if (value is num || value is bool) return value.toString();
  return const JsonEncoder.withIndent('  ').convert(value);
}

abstract final class _ModelUi {
  static const gray50 = Color(0xFFF9FAFB);
  static const gray200 = Color(0xFFE5E7EB);
  static const gray500 = Color(0xFF6B7280);
  static const gray600 = Color(0xFF4B5563);
  static const gray700 = Color(0xFF374151);
  static const gray950 = Color(0xFF030712);
  static const orange = Color(0xFFEA580C);
  static const blue = Color(0xFF2563EB);
  static const green = Color(0xFF15803D);
}
