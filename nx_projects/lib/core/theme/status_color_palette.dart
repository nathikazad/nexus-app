import 'package:flutter/material.dart';

import 'package:nx_projects/domain/task/task_status.dart';
import 'package:nx_projects/core/theme/app_theme.dart';

Color statusForeground(TaskStatus s) {
  return switch (s) {
    TaskStatus.todo => AppColors.muted,
    TaskStatus.doing => AppColors.accent,
    TaskStatus.done => AppColors.ok,
    TaskStatus.blocked => AppColors.warn,
  };
}

Color? statusBackground(TaskStatus s) {
  return switch (s) {
    TaskStatus.todo => null,
    TaskStatus.doing => AppColors.accentSoft,
    TaskStatus.done => const Color(0x1E4ADE80),
    TaskStatus.blocked => const Color(0x1EFBBF24),
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
