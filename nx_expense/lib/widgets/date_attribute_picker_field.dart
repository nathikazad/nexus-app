import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app_theme.dart';
import '../util/format.dart';

/// Picker for `date`-key attributes (stores `YYYY-MM-DD`).
class DateAttributePickerField extends StatelessWidget {
  const DateAttributePickerField({
    super.key,
    required this.label,
    required this.controller,
    required this.decoration,
    required this.onPicked,
    this.padding = const EdgeInsets.all(16),
  });

  final String label;
  final TextEditingController controller;
  final InputDecoration decoration;
  final VoidCallback onPicked;
  final EdgeInsetsGeometry padding;

  Future<void> _openPicker(BuildContext context) async {
    final initial = initialDateForYmdOrIso(controller.text.trim());
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 15),
      lastDate: DateTime(now.year + 2),
    );
    if (picked == null) return;
    controller.text =
        '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    onPicked();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.slate700,
            ),
          ),
          const SizedBox(height: 8),
          ListenableBuilder(
            listenable: controller,
            builder: (context, _) {
              final empty = controller.text.trim().isEmpty;
              return Material(
                color: Colors.white,
                child: InkWell(
                  onTap: () => _openPicker(context),
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: decoration,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            empty ? 'Select date' : formatModelDate(controller.text.trim()),
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: empty ? AppColors.slate400 : AppColors.slate900,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 20,
                          color: AppColors.slate400,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
