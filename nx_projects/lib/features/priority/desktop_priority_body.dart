import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nx_projects/core/theme/app_theme.dart';
import 'package:nx_projects/core/theme/bucket_color_palette.dart';
import 'package:nx_projects/domain/task/task.dart';
import 'package:nx_projects/domain/task/task_bucket.dart';
import 'package:nx_projects/features/priority/priority_view_model.dart';
import 'package:nx_projects/features/priority/widgets/bucket_header.dart';
import 'package:nx_projects/features/priority/widgets/inline_add_row.dart';
import 'package:nx_projects/features/shared/widgets/desktop_task_row.dart';

/// Desktop: all priority buckets stacked with dense rows (`reference/desktop` pane-priority).
class DesktopPriorityBody extends ConsumerWidget {
  const DesktopPriorityBody({super.key, required this.onOpenTaskMenu});

  final void Function(BuildContext, WidgetRef, Task) onOpenTaskMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        BucketHeader(
          label: bucketLabel(b),
          count: s.count,
          hint: hint.isEmpty ? null : hint,
        ),
      );
      for (final t in tasks) {
        rank += 1;
        children.add(
          DesktopTaskRow(
            task: t,
            rankLabel: '$rank',
            sprintChipLabel: desktopSprintChipLabelForTask(t),
            onMenu: () => onOpenTaskMenu(context, ref, t),
          ),
        );
      }
      children.add(
        InlineAddRow(
          label: 'Add to ${bucketLabel(b)}',
          onTap: () {},
        ),
      );
    }

    children.add(
      const Padding(
        padding: EdgeInsets.fromLTRB(4, 16, 4, 40),
        child: Text(
          '● bug    ◉ feature    S14 / S15 = pinned to that sprint    ☆ = not in any sprint',
          style: TextStyle(
            fontSize: 11,
            color: AppColors.dim,
            height: 1.6,
          ),
        ),
      ),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 0, 20, 0),
      children: children,
    );
  }
}
