import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nx_projects/core/layout/is_desktop_layout.dart';
import 'package:nx_projects/domain/task/task.dart';
import 'package:nx_projects/features/daily/desktop_daily_body.dart';
import 'package:nx_projects/features/daily/mobile_daily_body.dart';

class DailyScreen extends ConsumerWidget {
  const DailyScreen({
    super.key,
    required this.onOpenTaskMenu,
    required this.onOpenTask,
  });

  final void Function(BuildContext, WidgetRef, Task) onOpenTaskMenu;
  final void Function(BuildContext, WidgetRef, Task) onOpenTask;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isDesktopLayout(context)) {
      return DesktopDailyBody(
        onOpenTaskMenu: onOpenTaskMenu,
        onOpenTask: onOpenTask,
      );
    }
    return MobileDailyBody(onOpenTaskMenu: onOpenTaskMenu);
  }
}
