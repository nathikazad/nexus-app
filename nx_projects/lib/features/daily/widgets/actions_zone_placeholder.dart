import 'package:flutter/material.dart';

import 'package:nx_projects/core/theme/app_theme.dart';

/// Right column for time-tracking / actions. `nx_projects` has no [Action] model yet — layout only.
class ActionsZonePlaceholder extends StatelessWidget {
  const ActionsZonePlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
        boxShadow: const [BoxShadow(offset: Offset(0, 2), blurRadius: 12, color: Color(0x32000000))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ACTIONS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: null,
              style: FilledButton.styleFrom(
                disabledBackgroundColor: const Color(0x1E6AA3FF),
                disabledForegroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: Color(0x596AA3FF)),
                ),
              ),
              child: const Text('Start work', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text(
              'Time tracking lives in nx_time. Wire Actions here when the domain is shared.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.dim,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
