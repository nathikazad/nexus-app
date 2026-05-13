import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:nx_expense/core/theme/app_theme.dart';
import 'package:nx_expense/data/schema/kgql_schema_helpers.dart';
import 'package:nx_expense/domain/schema/model_type_view.dart';
import 'date_attribute_picker_field.dart';

/// One schema attribute row for Expense / Transfer create–edit forms (boolean, number, date, string).
class ModelAttributeFormField extends StatelessWidget {
  const ModelAttributeFormField({
    super.key,
    required this.attribute,
    required this.controller,
    required this.onChanged,
    required this.inputDecoration,
  });

  final AttributeDefView attribute;
  final TextEditingController controller;
  final VoidCallback onChanged;
  final InputDecoration inputDecoration;

  @override
  Widget build(BuildContext context) {
    final ad = attribute;
    final c = controller;
    final vt = ad.valueType ?? 'string';
    if (vt == 'boolean') {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                formatAttributeLabel(ad.key ?? ''),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.slate700,
                ),
              ),
            ),
            Switch(
              value: c.text == 'true',
              onChanged: (v) {
                c.text = v ? 'true' : 'false';
                onChanged();
              },
            ),
          ],
        ),
      );
    }
    if (vt == 'number') {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                formatAttributeLabel(ad.key ?? ''),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.slate700,
                ),
              ),
            ),
            SizedBox(
              width: 120,
              child: TextField(
                controller: c,
                textAlign: TextAlign.right,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: AppColors.slate900,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: InputDecoration(
                  prefixText: r'$ ',
                  prefixStyle: GoogleFonts.inter(
                    color: AppColors.slate400,
                    fontWeight: FontWeight.w500,
                  ),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    if ((ad.key ?? '').toLowerCase() == 'date') {
      return DateAttributePickerField(
        label: formatAttributeLabel(ad.key ?? ''),
        controller: c,
        decoration: inputDecoration,
        onPicked: onChanged,
      );
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formatAttributeLabel(ad.key ?? ''),
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.slate700,
            ),
          ),
          const SizedBox(height: 8),
          TextField(controller: c, decoration: inputDecoration),
        ],
      ),
    );
  }
}
