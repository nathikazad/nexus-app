import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nx_projects/core/theme/app_theme.dart';
import 'package:nx_projects/core/theme/bucket_color_palette.dart';
import 'package:nx_projects/data/providers.dart';
import 'package:nx_projects/domain/task/task.dart';
import 'package:nx_projects/features/desktop/desktop_drawer_controller.dart';
import 'package:nx_projects/features/desktop/desktop_pane_task_scroller.dart';
import 'package:nx_projects/features/desktop/desktop_task_locator.dart';
import 'package:nx_projects/domain/task/task_bucket.dart';
import 'package:nx_projects/features/filters/filter_state_providers.dart';
import 'package:nx_projects/features/priority/priority_view_model.dart';
import 'package:nx_projects/features/priority/widgets/bucket_header.dart';
import 'package:nx_projects/features/priority/widgets/inline_add_row.dart';
import 'package:nx_projects/features/shared/widgets/desktop_task_row.dart';

/// Desktop: all priority buckets stacked with dense rows (`reference/desktop` pane-priority).
class DesktopPriorityBody extends ConsumerStatefulWidget {
  const DesktopPriorityBody({super.key, required this.onOpenTaskMenu});

  final void Function(BuildContext, WidgetRef, Task) onOpenTaskMenu;

  @override
  ConsumerState<DesktopPriorityBody> createState() =>
      _DesktopPriorityBodyState();
}

class _DesktopPriorityBodyState extends ConsumerState<DesktopPriorityBody> {
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
            effect.surface != DesktopTaskLocatorSurface.planner ||
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
    final q = ref.watch(searchQueryProvider);
    final searchActive = q.trim().isNotEmpty;
    final sprints = ref.watch(sprintsListProvider);
    final locator = ref.watch(desktopTaskLocatorProvider);

    const order = <TaskBucket>[
      TaskBucket.now,
      TaskBucket.next,
      TaskBucket.later,
      TaskBucket.someday,
      TaskBucket.unsorted,
    ];

    var rank = 0;
    final children = <Widget>[];

    for (final b in order) {
      final tasks = ref.watch(priorityBucketTasksProvider(b));
      final summaries = ref.watch(priorityBucketsProvider);
      final s = summaries.firstWhere((x) => x.bucket == b);
      final hint = bucketHintDesktop(b);
      children.add(
        Opacity(
          opacity: searchActive ? 0.5 : 1,
          child: BucketHeader(
            label: bucketLabel(b),
            count: s.count,
            hint: hint.isEmpty ? null : hint,
          ),
        ),
      );
      for (final t in tasks) {
        rank += 1;
        children.add(
          SizedBox(
            key: _taskScroller.rowKeyFor(t.id),
            child: DesktopTaskRow(
              task: t,
              rankLabel: '$rank',
              sprintChipLabel: desktopSprintChipLabelForTask(t, sprints),
              isSearchMatch: _titleMatchesSearch(t, q),
              isLocated: locator.isHighlighted(t.id),
              onRowTap: () =>
                  ref.read(desktopDrawerControllerProvider).viewTask(t.id),
              onMenu: () => widget.onOpenTaskMenu(context, ref, t),
            ),
          ),
        );
      }
      children.add(
        Opacity(
          opacity: searchActive ? 0.5 : 1,
          child: InlineAddRow(label: 'Add to ${bucketLabel(b)}', onTap: () {}),
        ),
      );
    }

    children.add(
      const Padding(
        padding: EdgeInsets.fromLTRB(4, 16, 4, 40),
        child: Text(
          '● bug    ◉ feature    sprint chip = first + last two chars of sprint name    ☆ = not in any sprint',
          style: TextStyle(fontSize: 11, color: AppColors.dim, height: 1.6),
        ),
      ),
    );

    return SingleChildScrollView(
      controller: _taskScroller.controller,
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

bool _titleMatchesSearch(Task t, String q) {
  final s = q.trim().toLowerCase();
  if (s.isEmpty) return false;
  return t.title.toLowerCase().contains(s);
}
