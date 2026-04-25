import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nx_projects/core/layout/is_desktop_layout.dart';
import 'package:nx_projects/domain/task/task.dart';
import 'package:nx_projects/features/projects/desktop_projects_body.dart';
import 'package:nx_projects/features/projects/mobile_projects_body.dart';

class ProjectsScreen extends ConsumerWidget {
  const ProjectsScreen({super.key, required this.onOpenTaskMenu});

  final void Function(BuildContext, WidgetRef, Task) onOpenTaskMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isDesktopLayout(context)) {
      return DesktopProjectsBody(onOpenTaskMenu: onOpenTaskMenu);
    }
    return MobileProjectsBody(onOpenTaskMenu: onOpenTaskMenu);
  }
}
