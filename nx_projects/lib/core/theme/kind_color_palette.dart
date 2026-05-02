import 'package:flutter/material.dart';

import 'package:nx_projects/domain/task/task_kind.dart';
import 'package:nx_projects/core/theme/app_theme.dart';

Color kindColor(BuildContext context, TaskKind k) {
  return switch (k) {
    TaskKind.task => context.colors.muted,
    TaskKind.feat => context.colors.feat,
    TaskKind.bug => context.colors.bug,
  };
}

String kindLabel(TaskKind k) {
  return switch (k) {
    TaskKind.task => 'Task',
    TaskKind.feat => 'Feat',
    TaskKind.bug => 'Bug',
  };
}
