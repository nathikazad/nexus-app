import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nx_projects/domain/task/task.dart';
import 'package:nx_projects/features/desktop/desktop_drawer_controller.dart';
import 'package:nx_projects/features/daily/daily_screen.dart';
import 'package:nx_projects/features/shared/widgets/context_sheet.dart';

/// Full-width Today / Daily (`reference/desktop` `view-today` root).
class TodayView extends ConsumerWidget {
  const TodayView({super.key});

  void _openTaskMenu(BuildContext context, WidgetRef ref, Task t) {
    showTaskContextSheet(context, ref, task: t, onAfterChange: () {});
  }

  void _openTask(BuildContext context, WidgetRef ref, Task t) {
    ref.read(desktopDrawerControllerProvider).viewTask(t.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DailyScreen(onOpenTaskMenu: _openTaskMenu, onOpenTask: _openTask);
  }
}
