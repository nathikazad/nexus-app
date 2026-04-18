import 'package:flutter/material.dart';

import 'package:nx_time/features/action_detail/action_detail_view_model.dart';

/// Colored pill for the action subtype on the detail screen.
class DetailCategoryPill extends StatelessWidget {
  const DetailCategoryPill({super.key, required this.args});

  final ActivityDetailArgs args;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: args.categoryPillBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: args.categoryDotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            args.categoryPillLabel,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: args.categoryPillForeground,
            ),
          ),
        ],
      ),
    );
  }
}
