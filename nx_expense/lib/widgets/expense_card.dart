import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nx_db/nx_db.dart';

import '../app_theme.dart';
import '../reference_layout.dart';
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

    String? vendorNames;
    if (model.relations != null && model.relations!.isNotEmpty) {
      final first = model.relations!.entries.first;
      vendorNames = first.value.map((m) => m.name).join(', ');
    }

    return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(RefLayout.rounded2xl),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(RefLayout.rounded2xl),
              border: Border.all(color: AppColors.slate100),
              boxShadow: refCardShadow,
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        model.name,
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
                          color: AppColors.teal600,
                        ),
                      ),
                  ],
                ),
                if (vendorNames != null && vendorNames.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    vendorNames,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.slate500,
                    ),
                  ),
                ] else if (model.relations != null && model.relations!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    model.relations!.entries
                        .map((e) => e.value.map((m) => m.name).join(', '))
                        .join(' \u00b7 '),
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.slate500),
                  ),
                ],
                if (model.tags != null && model.tags!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final e in model.tags!.entries)
                        for (final node in e.value)
                          ExpenseTagChip(label: node),
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
