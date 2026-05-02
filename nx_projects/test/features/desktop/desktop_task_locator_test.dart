import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nx_projects/features/desktop/desktop_task_locator.dart';

void main() {
  test('locate emits a one-shot effect and pins highlight', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container
        .read(desktopTaskLocatorProvider.notifier)
        .locate(
          source: DesktopTaskLocateSource.sprintCart,
          surface: DesktopTaskLocatorSurface.planner,
          taskId: 42,
        );

    final state = container.read(desktopTaskLocatorProvider);
    expect(state.isHighlighted(42), isTrue);
    expect(state.locateEffect?.source, DesktopTaskLocateSource.sprintCart);
    expect(state.locateEffect?.surface, DesktopTaskLocatorSurface.planner);
    expect(state.locateEffect?.taskId, 42);
    expect(state.locateEffect?.serial, 1);
    expect(state.locateEffect?.isOneShot, isTrue);
  });

  test('locate effects get unique serials', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final locator = container.read(desktopTaskLocatorProvider.notifier);

    locator.locate(
      source: DesktopTaskLocateSource.sprintCart,
      surface: DesktopTaskLocatorSurface.planner,
      taskId: 1,
    );
    final first = container.read(desktopTaskLocatorProvider).locateEffect;

    locator.locate(
      source: DesktopTaskLocateSource.sprintCart,
      surface: DesktopTaskLocatorSurface.sprint,
      taskId: 2,
    );
    final second = container.read(desktopTaskLocatorProvider).locateEffect;

    expect(first?.serial, 1);
    expect(second?.serial, 2);
    expect(second?.surface, DesktopTaskLocatorSurface.sprint);
    expect(second?.taskId, 2);
  });

  test('hover is persistent state separate from locate effects', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final locator = container.read(desktopTaskLocatorProvider.notifier);

    locator.hover(7);
    expect(container.read(desktopTaskLocatorProvider).isHighlighted(7), isTrue);
    expect(container.read(desktopTaskLocatorProvider).locateEffect, isNull);

    locator.hover(null);
    expect(
      container.read(desktopTaskLocatorProvider).isHighlighted(7),
      isFalse,
    );
  });

  test('pinned highlight clears after the flash timer', () {
    fakeAsync((async) {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container
          .read(desktopTaskLocatorProvider.notifier)
          .locate(
            source: DesktopTaskLocateSource.sprintCart,
            surface: DesktopTaskLocatorSurface.planner,
            taskId: 9,
          );
      expect(
        container.read(desktopTaskLocatorProvider).isHighlighted(9),
        isTrue,
      );

      async.elapse(const Duration(milliseconds: 1600));
      expect(
        container.read(desktopTaskLocatorProvider).isHighlighted(9),
        isFalse,
      );
      expect(
        container.read(desktopTaskLocatorProvider).locateEffect?.taskId,
        9,
      );
    });
  });
}
