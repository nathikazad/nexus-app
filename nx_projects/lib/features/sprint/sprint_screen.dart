import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nx_projects/core/layout/is_desktop_layout.dart';
import 'package:nx_projects/domain/task/task.dart';
import 'package:nx_projects/features/sprint/desktop_sprint_body.dart';
import 'package:nx_projects/features/sprint/mobile_sprint_body.dart';

class SprintScreen extends ConsumerWidget {
  const SprintScreen({super.key, required this.onOpenTaskMenu});

  final void Function(BuildContext, WidgetRef, Task) onOpenTaskMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isDesktopLayout(context)) {
      return DesktopSprintBody(onOpenTaskMenu: onOpenTaskMenu);
    }
    return MobileSprintBody(onOpenTaskMenu: onOpenTaskMenu);
  }
}
