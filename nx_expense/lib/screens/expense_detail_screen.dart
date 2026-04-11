import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nx_db/nx_db.dart';

import '../expense_schema.dart';
import '../format.dart';
import '../providers/expense_providers.dart';
import '../widgets/tag_chip.dart';

class ExpenseDetailScreen extends ConsumerWidget {
  const ExpenseDetailScreen({super.key, required this.expenseId});

  final int expenseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schemaAsync = ref.watch(expenseSchemaProvider);
    final modelAsync = ref.watch(expenseDetailProvider(expenseId));

    return schemaAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (schema) {
        return modelAsync.when(
          loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (e, _) => Scaffold(
            appBar: AppBar(),
            body: Center(child: SelectableText('$e')),
          ),
          data: (model) {
            if (model == null) {
              return Scaffold(
                appBar: AppBar(),
                body: const Center(child: Text('Expense not found')),
              );
            }
            return _DetailBody(schema: schema, model: model, expenseId: expenseId);
          },
        );
      },
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({
    required this.schema,
    required this.model,
    required this.expenseId,
  });

  final ModelType schema;
  final Model model;
  final int expenseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final primaryKey = primaryNumberAttributeKey(schema);
    num? headerAmount;
    if (primaryKey != null) {
      final v = attributeValue(model, primaryKey);
      if (v is num) headerAmount = v;
      if (v is String) headerAmount = num.tryParse(v);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(model.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => context.push('/expense/form/$expenseId'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (headerAmount != null)
            Text(
              formatMoney(headerAmount),
              style: t.headlineMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          if (model.createdAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(formatModelDateTime(model.createdAt), style: t.bodyMedium),
            ),
          if (model.description != null && model.description!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Description', style: t.titleSmall),
            Text(model.description!),
          ],
          const SizedBox(height: 16),
          Text('Attributes', style: t.titleMedium),
          for (final ad in schema.attributes ?? const <AttributeDefinition>[]) ...[
            if (ad.key != null && ad.key != primaryKey)
              ListTile(
                title: Text(ad.key!),
                subtitle: Text(_formatAttr(model, ad.key!)),
              ),
          ],
          const SizedBox(height: 8),
          Text('Tags', style: t.titleMedium),
          if (model.tags == null || model.tags!.isEmpty)
            Text('None', style: t.bodySmall?.copyWith(color: t.bodySmall?.color?.withValues(alpha: 0.6)))
          else
            for (final sys in schema.tagSystems ?? const <TagSystem>[]) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(sys.name, style: t.titleSmall),
              ),
              if ((model.tags![sys.name] ?? []).isEmpty)
                Text('None', style: t.bodySmall)
              else
                Wrap(
                  spacing: 6,
                  children: [
                    for (final node in model.tags![sys.name]!)
                      ExpenseTagChip(
                        label: () {
                          final path = tagBreadcrumbPath(sys, node);
                          return path != null && path.length > 1 ? path.join(' › ') : node;
                        }(),
                      ),
                  ],
                ),
            ],
          const SizedBox(height: 8),
          Text('Relations', style: t.titleMedium),
          if (model.relations == null || model.relations!.isEmpty)
            Text('None', style: t.bodySmall)
          else
            for (final e in model.relations!.entries)
              ListTile(
                title: Text(e.key),
                subtitle: Text(e.value.map((m) => m.name).join(', ')),
              ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete expense'),
            style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete expense?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                  ],
                ),
              );
              if (ok != true || !context.mounted) return;
              final req = SetModelRequest(id: expenseId, delete: true);
              try {
                await createModel(ref.container, req);
                ref.invalidate(expenseListForUiProvider);
                ref.invalidate(expenseSummaryProvider);
                if (context.mounted) {
                  context.go('/expenses');
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                }
              }
            },
          ),
        ],
      ),
    );
  }

  String _formatAttr(Model model, String key) {
    final v = attributeValue(model, key);
    if (v == null) return '—';
    if (v is bool) return v ? 'Yes' : 'No';
    return v.toString();
  }
}
