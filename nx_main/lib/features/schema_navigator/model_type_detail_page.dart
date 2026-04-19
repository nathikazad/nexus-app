import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nexus_voice_assistant/core/theme/app_theme.dart';
import 'package:nexus_voice_assistant/data/providers.dart';
import 'package:nx_db/riverpod.dart' show modelTypeProvider, modelTypesProvider;
import 'package:nexus_voice_assistant/domain/schema/attribute_definition_draft.dart';
import 'package:nexus_voice_assistant/domain/schema/relation_definition_draft.dart';
import 'package:nexus_voice_assistant/domain/schema/schema_model_type.dart';
import 'package:nexus_voice_assistant/domain/schema/schema_tag_system_summary.dart';
import 'package:nexus_voice_assistant/core/widgets/error_widget.dart';
import 'package:nexus_voice_assistant/core/widgets/loading_indicator.dart';

/// Formats attribute keys for display (e.g. `first_name` → `First Name`).
String _formatAttributeKey(String? key) {
  if (key == null || key.isEmpty) return '—';
  return key
      .split('_')
      .map((word) {
        if (word.isEmpty) return word;
        final lower = word.toLowerCase();
        return '${lower[0].toUpperCase()}${lower.length > 1 ? lower.substring(1) : ''}';
      })
      .join(' ');
}

/// Read-only inspector for a model type (see reference/navigator/model-type-detail.html).
class ModelTypeDetailPage extends ConsumerWidget {
  const ModelTypeDetailPage({super.key, required this.modelTypeId});

  final int modelTypeId;

  static const _purple400 = Color(0xFFC084FC);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(schemaModelTypeProvider(modelTypeId));

    return async.when(
      data: (modelType) {
        if (modelType == null) {
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
              ),
              title: const Text('Model type'),
            ),
            body: Center(
              child: Text(
                'Not found',
                style: GoogleFonts.inter(color: AppColors.gray500),
              ),
            ),
          );
        }
        return _buildScaffold(context, ref, modelType);
      },
      loading: () => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          title: const Text('Model type'),
        ),
        body: const LoadingIndicator(),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          title: const Text('Model type'),
        ),
        body: ErrorDisplay(
          message: e.toString(),
          onRetry: () => ref.invalidate(modelTypeProvider(modelTypeId)),
        ),
      ),
    );
  }

  Widget _buildScaffold(
    BuildContext context,
    WidgetRef ref,
    SchemaModelType modelType,
  ) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(modelType.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit',
            onPressed: () async {
              final result = await context.push<bool>(
                '/model-type-form?modelTypeId=${modelType.id}',
              );
              if (result == true && context.mounted) {
                ref.invalidate(modelTypeProvider(modelTypeId));
                ref.invalidate(modelTypesProvider);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete',
            onPressed: () =>
                _confirmDeleteModelType(context, ref, modelType),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(modelTypeProvider(modelTypeId));
          ref.invalidate(modelTypesProvider);
          await ref.read(schemaModelTypeProvider(modelTypeId).future);
        },
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (modelType.typeKind == 'base') ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => context.push('/models/${modelType.id}'),
                  icon: const Icon(Icons.list_alt_rounded, size: 20),
                  label: const Text('View instances'),
                ),
              ),
              const SizedBox(height: 20),
            ],
            _metaRow(context, modelType),
            if (modelType.description != null && modelType.description!.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                modelType.description!,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.5,
                  color: AppColors.gray600,
                ),
              ),
            ],
            if (modelType.traits != null && modelType.traits!.isNotEmpty) ...[
              const SizedBox(height: 24),
              _sectionTitle('Traits'),
              const SizedBox(height: 8),
              ...modelType.traits!.map((t) => _traitTile(context, t)),
            ],
            if (modelType.attributes != null && modelType.attributes!.isNotEmpty) ...[
              const SizedBox(height: 24),
              _sectionTitle('Attributes'),
              const SizedBox(height: 8),
              _attributeCard(modelType.attributes!, muted: false),
            ],
            _inheritedSection(context, ref, modelType),
            if (modelType.relations != null && modelType.relations!.isNotEmpty) ...[
              const SizedBox(height: 24),
              _sectionTitle('Relations'),
              const SizedBox(height: 8),
              ...modelType.relations!.map((r) => _relationCard(context, ref, r)),
            ],
            if (modelType.tagSystems != null && modelType.tagSystems!.isNotEmpty) ...[
              const SizedBox(height: 24),
              _sectionTitle('Tag systems'),
              const SizedBox(height: 8),
              ...modelType.tagSystems!.map(_tagSystemCard),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _metaRow(BuildContext context, SchemaModelType modelType) {
    final kind = modelType.typeKind ?? '—';
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.orange50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            kind,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.orange600,
            ),
          ),
        ),
        if (modelType.parent != null)
          Text.rich(
            TextSpan(
              style: GoogleFonts.inter(fontSize: 14, color: AppColors.gray500),
              children: [
                const TextSpan(text: 'Parent: '),
                WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: GestureDetector(
                    onTap: () => context.push('/model-type/${modelType.parent!.id}'),
                    child: Text(
                      modelType.parent!.name,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.orange600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
        color: AppColors.gray400,
      ),
    );
  }

  Widget _traitTile(BuildContext context, SchemaModelType trait) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => context.push('/model-type/${trait.id}'),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.gray100),
            ),
            child: Row(
              children: [
                const Icon(Icons.tag, size: 18, color: _purple400),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    trait.name,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.gray900,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, size: 20, color: AppColors.gray400),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _attributeCard(
    List<AttributeDefinitionDraft> attrs, {
    required bool muted,
  }) {
    final textColor = muted ? AppColors.gray600 : AppColors.gray900;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gray100),
      ),
      child: Column(
        children: [
          for (var i = 0; i < attrs.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.gray100),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _formatAttributeKey(attrs[i].key),
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: textColor,
                      ),
                    ),
                  ),
                  if (attrs[i].valueType != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: AppColors.gray50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        attrs[i].valueType!,
                        style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray400),
                      ),
                    ),
                  if (attrs[i].required)
                    Text(
                      'required',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: muted ? AppColors.orange600.withValues(alpha: 0.85) : AppColors.orange600,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _inheritedSection(
    BuildContext context,
    WidgetRef ref,
    SchemaModelType modelType,
  ) {
    final parentId = modelType.parentId;
    if (parentId == null) return const SizedBox.shrink();

    final parentAsync = ref.watch(schemaModelTypeProvider(parentId));
    return parentAsync.when(
      data: (parent) {
        if (parent == null ||
            parent.attributes == null ||
            parent.attributes!.isEmpty) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Text.rich(
              TextSpan(
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  color: AppColors.gray400,
                ),
                children: [
                  const TextSpan(text: 'INHERITED ATTRIBUTES '),
                  TextSpan(
                    text: 'from ${parent.name}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0,
                      color: AppColors.gray400,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Opacity(
              opacity: 0.6,
              child: _attributeCard(parent.attributes!, muted: true),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _relationCard(
    BuildContext context,
    WidgetRef ref,
    RelationDefinitionDraft r,
  ) {
    final nameToId = ref.watch(schemaModelTypeNameToIdProvider);
    final targetName = _relationTargetName(r.link);
    final targetId = r.link is int
        ? r.link as int
        : (targetName != null ? nameToId[targetName] : null);
    final canNavigate = targetId != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: canNavigate ? () => context.push('/model-type/$targetId') : null,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.gray100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              targetName ?? targetId?.toString() ?? 'Relation',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.gray900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(Icons.arrow_forward, size: 16, color: AppColors.gray400),
                        ],
                      ),
                    ),
                    if (r.multiplicity != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.gray50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          r.multiplicity!,
                          style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray400),
                        ),
                      ),
                  ],
                ),
                if (r.description != null && r.description!.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    r.description!,
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.gray500),
                  ),
                ],
                if (r.relationAttributeDefinitions != null &&
                    r.relationAttributeDefinitions!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Relation attrs:',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.gray400,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: r.relationAttributeDefinitions!.map((a) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.gray50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${_formatAttributeKey(a.key)} · ${a.valueType}',
                              style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray500),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _relationTargetName(dynamic link) {
    if (link is String) return link;
    return null;
  }

  Widget _tagSystemCard(SchemaTagSystemSummary ts) {
    final selectionLabel = ts.selectionMode.toLowerCase() == 'exclusive'
        ? 'Exclusive'
        : 'Multiple';
    final structureLabel = ts.isHierarchical ? 'Hierarchical' : 'Flat';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.gray100),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                ts.name,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.gray900,
                ),
              ),
            ),
            Row(
              children: [
                _smallChip(selectionLabel),
                const SizedBox(width: 8),
                _smallChip(structureLabel),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _smallChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray400),
      ),
    );
  }
}

Future<void> _confirmDeleteModelType(
  BuildContext context,
  WidgetRef ref,
  SchemaModelType modelType,
) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete model type'),
      content: Text('Delete “${modelType.name}”? This cannot be undone.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(ctx).colorScheme.error,
          ),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  try {
    await ref.read(modelTypeWriteRepositoryProvider).deleteModelType(modelType.id);
    ref.invalidate(modelTypesProvider);
    ref.invalidate(modelTypeProvider(modelType.id));
    if (context.mounted) {
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted “${modelType.name}”')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete: $e')),
      );
    }
  }
}
