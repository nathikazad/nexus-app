import 'package:flutter/material.dart';

import 'package:nx_projects/core/theme/app_theme.dart';

/// `reference/desktop/styles.css` `.inline-add`
class InlineAddRow extends StatelessWidget {
  InlineAddRow({super.key, required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: context.colors.border),
            ),
            child: Row(
              children: [
                Text(
                  '+',
                  style: TextStyle(
                    color: context.colors.accent,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(fontSize: 12, color: context.colors.dim),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
