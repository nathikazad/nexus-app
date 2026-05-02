import 'package:flutter/material.dart';

import 'package:nx_projects/domain/task/task_bucket.dart';
import 'package:nx_projects/core/theme/app_theme.dart';

Color bucketColor(BuildContext context, TaskBucket b) {
  return switch (b) {
    TaskBucket.now => context.colors.accent,
    TaskBucket.next => context.colors.feat,
    TaskBucket.later => context.colors.muted,
    TaskBucket.someday => context.colors.dim,
    TaskBucket.unsorted => context.colors.dim,
  };
}

String bucketLabel(TaskBucket b) {
  return switch (b) {
    TaskBucket.now => 'NOW',
    TaskBucket.next => 'NEXT',
    TaskBucket.later => 'LATER',
    TaskBucket.someday => 'SOMEDAY',
    TaskBucket.unsorted => 'UNSORTED',
  };
}
