import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nx_projects/domain/task/task_bucket.dart';
import 'package:nx_projects/features/desktop/desktop_drawer_controller.dart';
import 'package:nx_projects/features/desktop/desktop_navigation_controller.dart';
import 'package:nx_projects/features/desktop/desktop_task_drawer_state.dart';
import 'package:nx_projects/features/shell/selection_providers.dart';

void main() {
  test('desktop navigation owns top-level and planner-mode intents', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final navigation = container.read(desktopNavigationControllerProvider);

    container.read(selectedProjectIdProvider.notifier).set(10);
    container.read(selectedSubProjectIdProvider.notifier).set(11);
    container.read(selectedPriorityBucketProvider.notifier).set(TaskBucket.now);

    navigation.showSprint();

    expect(container.read(desktopViewIndexProvider), DesktopView.sprint.index);
    expect(container.read(selectedProjectIdProvider), isNull);
    expect(container.read(selectedSubProjectIdProvider), isNull);
    expect(container.read(selectedPriorityBucketProvider), isNull);

    navigation.showPlannerPane(DesktopPlannerPane.priority);
    expect(
      container.read(desktopPlannerModeProvider),
      DesktopPlannerPane.priority.index,
    );
  });

  test('desktop drawer controller owns drawer intents', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final drawer = container.read(desktopDrawerControllerProvider);

    drawer.viewTask(123);
    expect(
      container.read(desktopTaskDrawerProvider),
      isA<DesktopTaskViewing>(),
    );
    expect(
      (container.read(desktopTaskDrawerProvider) as DesktopTaskViewing).taskId,
      123,
    );

    drawer.newTask(defaultProject: 1, defaultSub: 2);
    final creating = container.read(desktopTaskDrawerProvider);
    expect(creating, isA<DesktopTaskCreating>());
    expect((creating as DesktopTaskCreating).defaultProject, 1);
    expect(creating.defaultSub, 2);

    drawer.close();
    expect(
      container.read(desktopTaskDrawerProvider),
      isA<DesktopTaskDrawerClosed>(),
    );
  });
}
