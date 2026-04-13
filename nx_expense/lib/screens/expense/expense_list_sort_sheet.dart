import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app_theme.dart';
import '../../providers/expense_providers.dart';

class SortSheet extends StatelessWidget {
  const SortSheet({super.key, required this.current, required this.onPick});

  final ExpenseSortMode current;
  final void Function(ExpenseSortMode) onPick;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.slate200,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Sort by',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.slate900,
                ),
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.slate100),
          sortRow(
            icon: Icons.calendar_today_outlined,
            label: 'Date',
            ascMode: ExpenseSortMode.dateAsc,
            descMode: ExpenseSortMode.dateDesc,
          ),
          sortRow(
            icon: Icons.account_balance_wallet_outlined,
            label: 'Amount',
            ascMode: ExpenseSortMode.amountAsc,
            descMode: ExpenseSortMode.amountDesc,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget sortRow({
    required IconData icon,
    required String label,
    required ExpenseSortMode ascMode,
    required ExpenseSortMode descMode,
  }) {
    final isAsc = current == ascMode;
    final isDesc = current == descMode;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.slate400),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.slate900,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.slate50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.slate200),
            ),
            padding: const EdgeInsets.all(2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                toggleButton('Asc', isAsc, () => onPick(ascMode)),
                toggleButton('Desc', isDesc, () => onPick(descMode)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget toggleButton(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.teal600 : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.slate600,
          ),
        ),
      ),
    );
  }
}
