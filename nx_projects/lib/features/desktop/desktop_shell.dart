import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nx_projects/core/theme/app_theme.dart';
import 'package:nx_projects/features/desktop/widgets/desktop_topbar.dart';
import 'package:nx_projects/features/desktop/views/planner_view.dart';
import 'package:nx_projects/features/desktop/views/sprint_view.dart';
import 'package:nx_projects/features/desktop/views/today_view.dart';
import 'package:nx_projects/features/shell/selection_providers.dart';

/// Reference `reference/desktop/` — 44px top tabs + three full views.
class DesktopShell extends ConsumerWidget {
  const DesktopShell({super.key});

  void _resetDrill(WidgetRef ref) {
    ref.read(selectedProjectIdProvider.notifier).set(null);
    ref.read(selectedSubProjectIdProvider.notifier).set(null);
    ref.read(selectedPriorityBucketProvider.notifier).set(null);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(desktopViewIndexProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: AppColors.panel,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: AppColors.bg,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DesktopTopBar(
              activeIndex: view,
              onSelect: (i) {
                if (i != ref.read(desktopViewIndexProvider)) {
                  _resetDrill(ref);
                }
                ref.read(desktopViewIndexProvider.notifier).setView(i);
              },
            ),
            Expanded(
              child: IndexedStack(
                index: view,
                sizing: StackFit.expand,
                children: const [
                  PlannerView(),
                  DesktopSprintView(),
                  TodayView(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
