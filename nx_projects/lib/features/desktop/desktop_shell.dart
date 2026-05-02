import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nx_projects/core/theme/app_theme.dart';
import 'package:nx_projects/features/desktop/desktop_navigation_controller.dart';
import 'package:nx_projects/features/desktop/widgets/desktop_topbar.dart';
import 'package:nx_projects/features/desktop/views/planner_view.dart';
import 'package:nx_projects/features/desktop/views/sprint_view.dart';
import 'package:nx_projects/features/desktop/views/today_view.dart';
import 'package:nx_projects/features/shell/selection_providers.dart';

/// Reference `reference/desktop/` — 44px top tabs + three full views.
class DesktopShell extends ConsumerWidget {
  DesktopShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(desktopViewIndexProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: context.colors.panel,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: context.colors.bg,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: context.colors.bg,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DesktopTopBar(
              activeIndex: view,
              onSelect: (i) => ref
                  .read(desktopNavigationControllerProvider)
                  .showView(DesktopView.values[i]),
            ),
            Expanded(
              child: IndexedStack(
                index: view,
                sizing: StackFit.expand,
                children: [PlannerView(), DesktopSprintView(), TodayView()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
