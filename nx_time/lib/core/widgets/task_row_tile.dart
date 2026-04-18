import 'package:flutter/material.dart';
import 'package:solar_icon_pack/solar_icon_pack.dart';

import 'package:nx_time/app_theme.dart';

class TaskRowTile extends StatelessWidget {
  const TaskRowTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.durationLabel,
    required this.done,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final String durationLabel;
  final bool done;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: done
                ? DecoratedBox(
                    decoration: const BoxDecoration(
                      color: AppColors.slate900,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      SolarLinearIcons.checkRead,
                      size: 12,
                      color: Colors.white,
                    ),
                  )
                : Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.slate300),
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.slate900,
                    decoration: done ? TextDecoration.lineThrough : null,
                    decorationColor: AppColors.slate900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.slate500,
                  ),
                ),
              ],
            ),
          ),
          Text(
            durationLabel,
            style: TextStyle(
              fontSize: 12,
              fontWeight: done ? FontWeight.w400 : FontWeight.w500,
              color: AppColors.slate400,
            ),
          ),
        ],
      ),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Opacity(
          opacity: done ? 0.5 : 1,
          child: row,
        ),
      ),
    );
  }
}
