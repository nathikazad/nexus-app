import 'package:flutter/material.dart';

import 'package:nx_time/core/theme/app_theme.dart';

/// “Notes” heading + body when [text] is non-empty after trim.
class ActionDetailNotesBlock extends StatelessWidget {
  const ActionDetailNotesBlock({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Notes',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.slate500,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            height: 1.45,
            color: AppColors.slate700,
          ),
        ),
      ],
    );
  }
}
