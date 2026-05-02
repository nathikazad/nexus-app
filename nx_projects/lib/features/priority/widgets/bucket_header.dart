import 'package:flutter/material.dart';

import 'package:nx_projects/core/theme/app_theme.dart';
import 'package:nx_projects/domain/task/task_bucket.dart';

/// `reference/desktop/styles.css` `.bucket-h`
class BucketHeader extends StatelessWidget {
  BucketHeader({
    super.key,
    required this.label,
    required this.count,
    this.hint,
    this.expanded = true,
    this.onToggle,
  });
  final String label;
  final int count;
  final String? hint;
  final bool expanded;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: EdgeInsets.fromLTRB(4, 14, 4, 6),
        child: Row(
          children: [
            SizedBox(
              width: 10,
              child: Text(
                expanded ? '▾' : '▸',
                style: TextStyle(fontSize: 11, color: context.colors.muted),
              ),
            ),
            SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 0.8,
                color: context.colors.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(width: 8),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 7, vertical: 1),
              decoration: BoxDecoration(
                color: context.colors.panel2,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(fontSize: 10, color: context.colors.muted),
              ),
            ),
            if (hint != null && hint!.isNotEmpty) ...[
              Spacer(),
              Text(
                hint!,
                style: TextStyle(
                  fontSize: 10,
                  color: context.colors.dim,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String bucketHintDesktop(TaskBucket b) {
  return switch (b) {
    TaskBucket.now => 'do this sprint',
    TaskBucket.next => '1–2 sprints out',
    TaskBucket.later || TaskBucket.someday || TaskBucket.unsorted => '',
  };
}
