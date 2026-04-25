import 'package:flutter/material.dart';

import 'package:nx_projects/core/theme/app_theme.dart';
import 'package:nx_projects/core/theme/bucket_color_palette.dart';
import 'package:nx_projects/domain/task/task.dart';
import 'package:nx_projects/domain/task/task_bucket.dart';

/// `reference/desktop/styles.css` `.bkt` in crumb column
class DesktopBucketPill extends StatelessWidget {
  const DesktopBucketPill({super.key, required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    final b = task.bucket;
    if (b == TaskBucket.unsorted) {
      return const Text(
        'unsorted',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10,
          fontStyle: FontStyle.italic,
          color: AppColors.dim,
        ),
      );
    }
    return Text(
      b.name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        color: bucketColor(b),
      ),
    );
  }
}
