import 'package:flutter/material.dart';
import 'package:nx_db/nx_db.dart';

import '../expense_schema.dart';
import '../format.dart';
import 'tag_chip.dart';

class ExpenseCard extends StatelessWidget {
  const ExpenseCard({
    super.key,
    required this.model,
    required this.schema,
    required this.onTap,
  });

  final Model model;
  final ModelType schema;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primaryKey = primaryNumberAttributeKey(schema);
    num? amount;
    if (primaryKey != null) {
      final v = attributeValue(model, primaryKey);
      if (v is num) amount = v;
      if (v is String) amount = num.tryParse(v);
    }

    final t = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      model.name,
                      style: t.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (amount != null)
                    Text(
                      formatMoney(amount),
                      style: t.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                ],
              ),
              if (model.createdAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  formatModelDate(model.createdAt),
                  style: t.bodySmall?.copyWith(color: t.bodySmall?.color?.withValues(alpha: 0.8)),
                ),
              ],
              if (model.tags != null && model.tags!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (final e in model.tags!.entries)
                      for (final node in e.value)
                        ExpenseTagChip(label: '${e.key}: $node'),
                  ],
                ),
              ],
              if (model.relations != null && model.relations!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  model.relations!.entries
                      .map((e) => '${e.key}: ${e.value.map((m) => m.name).join(", ")}')
                      .join(' · '),
                  style: t.bodySmall?.copyWith(color: t.bodySmall?.color?.withValues(alpha: 0.7)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
