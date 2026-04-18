import 'package:flutter/material.dart';

import 'package:nx_time/app_theme.dart';
import 'package:nx_time/features/today/today_view_model.dart';

class CategoryLegend extends StatelessWidget {
  const CategoryLegend({super.key, required this.items});

  final List<ActivityCategory> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        for (final c in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: c.swatch,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                c.label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.slate500,
                ),
              ),
            ],
          ),
      ],
    );
  }
}
