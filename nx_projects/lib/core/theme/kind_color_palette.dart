import 'package:flutter/material.dart';

import 'package:nx_projects/domain/task/task_kind.dart';
import 'package:nx_projects/core/theme/app_theme.dart';

Color kindColor(TaskKind k) {
  return switch (k) {
    TaskKind.task => AppColors.muted,
    TaskKind.feat => AppColors.feat,
    TaskKind.bug => AppColors.bug,
  };
}

String kindLabel(TaskKind k) {
  return switch (k) {
    TaskKind.task => 'Task',
    TaskKind.feat => 'Feat',
    TaskKind.bug => 'Bug',
  };
}
