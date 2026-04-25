import 'package:flutter/material.dart';

import 'package:nx_projects/domain/task/task_bucket.dart';
import 'package:nx_projects/core/theme/app_theme.dart';

Color bucketColor(TaskBucket b) {
  return switch (b) {
    TaskBucket.now => AppColors.accent,
    TaskBucket.next => AppColors.feat,
    TaskBucket.later => AppColors.muted,
    TaskBucket.someday => AppColors.dim,
    TaskBucket.unsorted => AppColors.dim,
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
