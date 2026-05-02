import 'package:flutter/material.dart';

import 'package:nx_projects/core/formatting/hours_format.dart';
import 'package:nx_projects/core/theme/app_theme.dart';

class ProjectRow extends StatelessWidget {
  ProjectRow({
    super.key,
    required this.name,
    required this.color,
    required this.count,
    required this.hours,
    this.onTap,
  });

  final String name;
  final Color color;
  final int count;
  final double hours;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.panel,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.colors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                margin: EdgeInsets.only(right: 10),
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: context.colors.text,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '$count · ${formatHours(hours)}',
                style: TextStyle(fontSize: 11, color: context.colors.muted),
              ),
              SizedBox(width: 8),
              Icon(Icons.chevron_right, color: context.colors.dim, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
