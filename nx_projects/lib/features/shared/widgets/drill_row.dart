import 'package:flutter/material.dart';

import 'package:nx_projects/core/layout/layout.dart';
import 'package:nx_projects/core/theme/app_theme.dart';
import 'package:nx_projects/core/formatting/hours_format.dart';

/// Drill-down row: optional color dot, title, meta (e.g. "3 · 12h"), chevron.
class DrillRow extends StatelessWidget {
  DrillRow({
    super.key,
    required this.title,
    required this.meta,
    this.dotColor,
    this.isSub = false,
    this.onTap,
  });

  final String title;
  final String meta;
  final Color? dotColor;
  final bool isSub;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.panel,
      child: InkWell(
        onTap: onTap,
        borderRadius: NxLayout.cardRadius,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.colors.border),
          ),
          child: Row(
            children: [
              if (dotColor != null)
                Container(
                  width: isSub ? 6 : 10,
                  height: isSub ? 6 : 10,
                  margin: EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                )
              else
                SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: isSub ? 14 : 15,
                    fontWeight: isSub ? FontWeight.w500 : FontWeight.w600,
                    color: context.colors.text,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                meta,
                style: TextStyle(
                  fontSize: 11,
                  color: context.colors.muted,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
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

class BucketDrillRow extends StatelessWidget {
  BucketDrillRow({
    super.key,
    required this.label,
    required this.count,
    required this.hours,
    required this.dotColor,
    required this.onTap,
  });

  final String label;
  final int count;
  final double hours;
  final Color dotColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return DrillRow(
      title: label,
      meta: '$count · ${formatHours(hours)}',
      dotColor: dotColor,
      onTap: onTap,
    );
  }
}
