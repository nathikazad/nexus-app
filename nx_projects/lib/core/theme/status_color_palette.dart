import 'package:flutter/material.dart';

import 'package:nx_projects/domain/task/task_status.dart';
import 'package:nx_projects/core/theme/app_theme.dart';

Color statusForeground(BuildContext context, TaskStatus s) {
  return switch (s) {
    TaskStatus.todo => context.colors.muted,
    TaskStatus.doing => context.colors.accent,
    TaskStatus.done => context.colors.ok,
    TaskStatus.blocked => context.colors.warn,
  };
}

Color? statusBackground(BuildContext context, TaskStatus s) {
  return switch (s) {
    TaskStatus.todo => null,
    TaskStatus.doing => context.colors.accentSoft,
    TaskStatus.done => Color(0x1E4ADE80),
    TaskStatus.blocked => Color(0x1EFBBF24),
  };
}

String statusLabel(TaskStatus s) {
  return switch (s) {
    TaskStatus.todo => 'TODO',
    TaskStatus.doing => 'DOING',
    TaskStatus.done => 'DONE',
    TaskStatus.blocked => 'BLOCKED',
  };
}
