import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:nx_expense/core/theme/app_theme.dart';

class ExpenseTagChip extends StatelessWidget {
  const ExpenseTagChip({super.key, required this.label, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color ?? AppColors.slate100,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.2,
          color: AppColors.slate600,
        ),
      ),
    );
  }
}
