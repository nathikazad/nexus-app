import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app_theme.dart';
import '../providers/expense_providers.dart';
import '../layout.dart';

/// Returns true if [r] is exactly one calendar month (local date arithmetic).
bool isFullCalendarMonthRange(DateTimeRange r) {
  final s = DateTime(r.start.year, r.start.month, r.start.day);
  final e = DateTime(r.end.year, r.end.month, r.end.day);
  final monthStart = DateTime(s.year, s.month);
  final monthEnd = DateTime(s.year, s.month + 1).subtract(const Duration(days: 1));
  return s == monthStart && e == monthEnd && s.month == e.month && s.year == e.year;
}

/// Shared year + month pills + custom calendar for Dashboard and Expense list.
class ExpenseDateRangeBar extends ConsumerWidget {
  const ExpenseDateRangeBar({super.key, this.bottomPadding = 8});

  final double bottomPadding;

  static const _monthLabels = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(expenseDateRangeProvider);
    final displayMonth = range.start.month;
    final displayYear = range.start.year;

    void applyMonth(int month, int year) {
      final start = DateTime(year, month);
      final end = DateTime(year, month + 1).subtract(const Duration(days: 1));
      ref.read(expenseDateRangeProvider.notifier).setRange(DateTimeRange(start: start, end: end));
    }

    void applyYear(int year) {
      final start = DateTime(year, 1, 1);
      final end = DateTime(year, 12, 31, 23, 59, 59, 999);
      ref.read(expenseDateRangeProvider.notifier).setRange(DateTimeRange(start: start, end: end));
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(RefLayout.px5, 0, RefLayout.px5, bottomPadding),
      child: Row(
        children: [
          GestureDetector(
            onTap: () async {
              final now = DateTime.now();
              final years = List.generate(5, (i) => now.year - 2 + i);
              final picked = await showModalBottomSheet<int>(
                context: context,
                builder: (_) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final y in years)
                        ListTile(
                          title: Text('$y', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                          selected: y == displayYear,
                          selectedColor: AppColors.teal600,
                          onTap: () => Navigator.pop(context, y),
                        ),
                    ],
                  ),
                ),
              );
              if (picked != null && picked != displayYear) {
                applyYear(picked);
              }
            },
            child: Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.slate100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    '$displayYear',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.slate900,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(Icons.keyboard_arrow_down, size: 18, color: AppColors.slate500),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 12,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (context, i) {
                  final month = i + 1;
                  final isSingleMonth = isFullCalendarMonthRange(range);
                  final isSelected = isSingleMonth && month == displayMonth;
                  return GestureDetector(
                    onTap: () => applyMonth(month, displayYear),
                    child: Container(
                      height: 32,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.teal600 : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? AppColors.teal600 : AppColors.slate200,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppColors.teal600.withValues(alpha: 0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        _monthLabels[i],
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : AppColors.slate600,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Calendar icon that opens [showDateRangePicker] and writes [expenseDateRangeProvider].
class ExpenseDateRangeCalendarButton extends ConsumerWidget {
  const ExpenseDateRangeCalendarButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(expenseDateRangeProvider);
    final isCustom = !isFullCalendarMonthRange(range);

    return IconButton(
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      icon: Icon(
        Icons.calendar_today_outlined,
        color: isCustom ? AppColors.teal600 : AppColors.slate400,
        size: 22,
      ),
      onPressed: () async {
        final now = DateTime.now();
        final picked = await showDateRangePicker(
          context: context,
          firstDate: DateTime(now.year - 2),
          lastDate: DateTime(now.year + 1),
          initialDateRange: range,
        );
        if (picked != null) {
          ref.read(expenseDateRangeProvider.notifier).setRange(picked);
        }
      },
    );
  }
}
