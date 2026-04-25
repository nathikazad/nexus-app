import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nx_projects/core/layout/is_desktop_layout.dart';
import 'package:nx_projects/domain/task/task.dart';
import 'package:nx_projects/features/priority/desktop_priority_body.dart';
import 'package:nx_projects/features/priority/mobile_priority_body.dart';

class PriorityScreen extends ConsumerWidget {
  const PriorityScreen({super.key, required this.onOpenTaskMenu});

  final void Function(BuildContext, WidgetRef, Task) onOpenTaskMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isDesktopLayout(context)) {
      return DesktopPriorityBody(onOpenTaskMenu: onOpenTaskMenu);
    }
    return MobilePriorityBody(onOpenTaskMenu: onOpenTaskMenu);
  }
}
