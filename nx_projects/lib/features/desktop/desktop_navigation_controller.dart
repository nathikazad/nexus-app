import 'package:nx_projects/features/shell/selection_providers.dart';
import 'package:riverpod/riverpod.dart';

enum DesktopView { planner, sprint, today }

enum DesktopPlannerPane { projects, priority }

class DesktopNavigationController {
  const DesktopNavigationController(this._ref);

  final Ref _ref;

  void showView(DesktopView view) {
    final nextIndex = view.index;
    final currentIndex = _ref.read(desktopViewIndexProvider);
    if (nextIndex != currentIndex) {
      _clearDrilldown();
    }
    _ref.read(desktopViewIndexProvider.notifier).setView(nextIndex);
  }

  void showPlanner() => showView(DesktopView.planner);

  void showSprint() => showView(DesktopView.sprint);

  void showToday() => showView(DesktopView.today);

  void showPlannerPane(DesktopPlannerPane pane) {
    _ref.read(desktopPlannerModeProvider.notifier).setMode(pane.index);
  }

  void _clearDrilldown() {
    _ref.read(selectedProjectIdProvider.notifier).set(null);
    _ref.read(selectedSubProjectIdProvider.notifier).set(null);
    _ref.read(selectedPriorityBucketProvider.notifier).set(null);
  }
}

final desktopNavigationControllerProvider =
    Provider<DesktopNavigationController>(
      DesktopNavigationController.new,
      name: 'desktopNavigationControllerProvider',
    );
