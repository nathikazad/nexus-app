import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nx_projects/core/theme/app_theme.dart';
import 'package:nx_projects/domain/sprint/sprint.dart';
import 'package:nx_projects/domain/task/task.dart';
import 'package:nx_projects/features/desktop/desktop_drawer_controller.dart';
import 'package:nx_projects/features/desktop/desktop_pane_task_scroller.dart';
import 'package:nx_projects/features/desktop/desktop_task_locator.dart';
import 'package:nx_projects/features/sprint/sprint_view_model.dart';
import 'package:nx_projects/features/sprint/widgets/desktop_day_card.dart';

/// Desktop: sprint summary, plan heading, bordered day cards.
class DesktopSprintBody extends ConsumerStatefulWidget {
  DesktopSprintBody({super.key, required this.onOpenTaskMenu});

  final void Function(BuildContext, WidgetRef, Task) onOpenTaskMenu;

  @override
  ConsumerState<DesktopSprintBody> createState() => _DesktopSprintBodyState();
}

class _DesktopSprintBodyState extends ConsumerState<DesktopSprintBody> {
  ProviderSubscription<DesktopTaskLocatorState>? _locatorSub;
  final DesktopPaneTaskScroller _taskScroller = DesktopPaneTaskScroller();

  @override
  void initState() {
    super.initState();
    _locatorSub = ref.listenManual<DesktopTaskLocatorState>(
      desktopTaskLocatorProvider,
      (previous, next) {
        final effect = next.locateEffect;
        if (effect == null ||
            effect.surface != DesktopTaskLocatorSurface.sprint ||
            previous?.locateEffect?.serial == effect.serial) {
          return;
        }
        _taskScroller.scrollToTask(effect.taskId, isMounted: () => mounted);
      },
    );
  }

  @override
  void dispose() {
    _locatorSub?.close();
    _taskScroller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sp = ref.watch(currentSprintProvider);
    final days = ref.watch(sprintDaySlicesProvider);
    final allTasks = ref.watch(sprintTasksProvider);

    return SafeArea(
      child: SingleChildScrollView(
        controller: _taskScroller.controller,
        padding: EdgeInsets.fromLTRB(24, 16, 24, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DaysHead(sprint: sp),
            for (final day in days)
              DesktopDayCard(
                slice: day,
                sprint: sp,
                taskRowKeyFor: _taskScroller.rowKeyFor,
                onOpenTaskMenu: (t) => widget.onOpenTaskMenu(context, ref, t),
                onOpenTask: (t) =>
                    ref.read(desktopDrawerControllerProvider).viewTask(t.id),
              ),
            if (allTasks.isEmpty)
              Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    'No tasks in this sprint yet.',
                    style: TextStyle(
                      color: context.colors.dim,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DaysHead extends StatelessWidget {
  _DaysHead({required this.sprint});

  final Sprint sprint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(2, 0, 2, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'Plan',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: context.colors.text,
                        ),
                      ),
                      TextSpan(
                        text: ' · ${sprint.name}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w400,
                          color: context.colors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
