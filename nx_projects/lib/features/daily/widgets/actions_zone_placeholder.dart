import 'package:flutter/material.dart';

import 'package:nx_projects/core/theme/app_theme.dart';

/// Right column for time-tracking / actions. `nx_projects` has no [Action] model yet — layout only.
class ActionsZonePlaceholder extends StatelessWidget {
  ActionsZonePlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.panel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.colors.border),
        boxShadow: [
          BoxShadow(
            offset: Offset(0, 2),
            blurRadius: 12,
            color: Color(0x32000000),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ACTIONS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: context.colors.muted,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Divider(height: 1, color: context.colors.border),
          SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: null,
              style: FilledButton.styleFrom(
                disabledBackgroundColor: Color(0x1E6AA3FF),
                disabledForegroundColor: context.colors.accent,
                padding: EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Color(0x596AA3FF)),
                ),
              ),
              child: Text(
                'Start work',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text(
              'Time tracking lives in nx_time. Wire Actions here when the domain is shared.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.colors.dim,
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
