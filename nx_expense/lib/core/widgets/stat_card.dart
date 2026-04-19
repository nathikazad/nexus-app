import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:nx_expense/core/theme/app_theme.dart';

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    this.highlight = false,
  });

  final String title;
  final String value;
  final String? subtitle;
  /// Teal card for primary total (see reference dashboard).
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final titleStyle = GoogleFonts.inter(
      fontSize: 10,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.8,
      color: highlight ? AppColors.teal100 : AppColors.slate400,
    );
    final valueStyle = GoogleFonts.inter(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.5,
      color: highlight ? Colors.white : AppColors.slate900,
    );
    final useMoneySplit = highlight &&
        value.contains('.') &&
        (value.startsWith(r'$') || value.startsWith('-'));
    final valueWidget = useMoneySplit
        ? _splitMoneyHighlight(value)
        : Text(
            value,
            style: valueStyle,
            maxLines: 1,
            softWrap: false,
          );
    return Card(
      color: highlight ? AppColors.teal600 : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: highlight ? AppColors.teal700 : AppColors.slate100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title.toUpperCase(), style: titleStyle),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: valueWidget,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: highlight ? AppColors.teal100 : AppColors.slate500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Reference: `$1,240` + `.00` in smaller teal-300.
Widget _splitMoneyHighlight(String value) {
  final dot = value.lastIndexOf('.');
  if (dot <= 0 || dot >= value.length - 1) {
    return Text(
      value,
      style: GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
        color: Colors.white,
      ),
      maxLines: 1,
      softWrap: false,
    );
  }
  final main = value.substring(0, dot);
  final cents = value.substring(dot);
  return Text.rich(
    TextSpan(
      style: GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
        color: Colors.white,
      ),
      children: [
        TextSpan(text: main),
        TextSpan(
          text: cents,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF5EEAD4),
          ),
        ),
      ],
    ),
    maxLines: 1,
    softWrap: false,
  );
}
