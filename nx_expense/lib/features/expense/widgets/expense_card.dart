import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:nx_expense/core/theme/app_theme.dart';
import 'package:nx_expense/core/layout/layout.dart';
import 'package:nx_expense/domain/expense/expense.dart';
import 'package:nx_expense/domain/expense/model_names.dart';
import 'package:nx_expense/domain/schema/model_type_view.dart';
import 'package:nx_expense/data/schema/kgql_schema_helpers.dart';
import 'package:nx_expense/core/formatting/format.dart';
import 'tag_chip.dart';

class ExpenseCard extends StatelessWidget {
  const ExpenseCard({
    super.key,
    required this.expense,
    required this.schema,
    required this.onTap,
    this.selectionMode = false,
    this.selected = false,
  });

  final Expense expense;
  final ModelTypeView schema;
  final VoidCallback onTap;
  final bool selectionMode;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final primaryKey = schema.primaryNumberAttributeKey;
    num? amount;
    if (primaryKey != null) {
      final v = expense.attributes?[primaryKey];
      if (v is num) amount = v;
      if (v is String) amount = num.tryParse(v);
    }

    final ignored = expenseIgnoredForTotals(expense);
    final visibleRelations =
        expense.relations?.entries
            .where(
              (entry) =>
                  entry.key != kProductModelTypeName && entry.value.isNotEmpty,
            )
            .toList() ??
        const [];
    final borderColor = ignored
        ? Colors.red.shade200
        : (selectionMode && selected ? AppColors.teal600 : AppColors.slate100);
    final borderWidth = selectionMode && selected ? 2.0 : 1.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(RefLayout.rounded2xl),
        child: Container(
          decoration: BoxDecoration(
            color: ignored ? Colors.red.shade50 : Colors.white,
            borderRadius: BorderRadius.circular(RefLayout.rounded2xl),
            border: Border.all(color: borderColor, width: borderWidth),
            boxShadow: refCardShadow,
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (selectionMode) ...[
                    Padding(
                      padding: const EdgeInsets.only(right: 10, top: 2),
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: selected ? AppColors.teal600 : Colors.white,
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                              color: selected
                                  ? AppColors.teal600
                                  : AppColors.slate300,
                              width: 2,
                            ),
                          ),
                          child: selected
                              ? const Icon(
                                  Icons.check,
                                  size: 16,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                      ),
                    ),
                  ],
                  Expanded(
                    child: Text(
                      expense.name,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.slate900,
                      ),
                    ),
                  ),
                  if (amount != null)
                    Text(
                      formatMoney(amount),
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: ignored ? AppColors.slate500 : AppColors.teal600,
                        decoration: ignored ? TextDecoration.lineThrough : null,
                        decorationColor: AppColors.slate400,
                      ),
                    ),
                ],
              ),
              if (visibleRelations.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  visibleRelations
                      .map((e) => e.value.map((m) => m.name).join(', '))
                      .join(' \u00b7 '),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.slate500,
                  ),
                ),
              ],
              if (expense.tags != null && expense.tags!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final e in expense.tags!.entries)
                      for (final node in e.value) ExpenseTagChip(label: node),
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
