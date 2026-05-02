import 'package:flutter/material.dart';

import 'package:nx_projects/core/theme/app_theme.dart';

class ProjectKindSection extends StatelessWidget {
  ProjectKindSection({super.key, required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(6, 20, 6, 8),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 0.8,
              color: context.colors.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(width: 8),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: context.colors.panel2,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(fontSize: 10, color: context.colors.muted),
            ),
          ),
        ],
      ),
    );
  }
}
