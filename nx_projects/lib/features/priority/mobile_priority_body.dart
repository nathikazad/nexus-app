import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nx_projects/core/layout/layout.dart';
import 'package:nx_projects/core/theme/app_theme.dart';
import 'package:nx_projects/core/theme/bucket_color_palette.dart';
import 'package:nx_projects/domain/task/task.dart';
import 'package:nx_projects/domain/task/task_bucket.dart';
import 'package:nx_projects/features/priority/priority_view_model.dart';
import 'package:nx_projects/features/shared/widgets/drill_row.dart';
import 'package:nx_projects/features/shared/widgets/task_row.dart';
import 'package:nx_projects/features/shell/selection_providers.dart';

/// Mobile: bucket list → drill into one bucket's tasks.
class MobilePriorityBody extends ConsumerWidget {
  const MobilePriorityBody({super.key, required this.onOpenTaskMenu});

  final void Function(BuildContext, WidgetRef, Task) onOpenTaskMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bucket = ref.watch(selectedPriorityBucketProvider);
    if (bucket == null) {
      return _BucketList(
        onPick: (b) {
          ref.read(selectedPriorityBucketProvider.notifier).set(b);
        },
      );
    }
    return _BucketTasks(
      bucket: bucket,
      onOpenTaskMenu: onOpenTaskMenu,
    );
  }
}

class _BucketList extends ConsumerWidget {
  const _BucketList({required this.onPick});

  final void Function(TaskBucket) onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaries = ref.watch(priorityBucketsProvider);
    return ListView(
      padding: NxLayout.contentPadding,
      children: [
        for (final s in summaries)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: BucketDrillRow(
              label: bucketLabel(s.bucket),
              count: s.count,
              hours: s.hours,
              dotColor: bucketColor(s.bucket),
              onTap: () => onPick(s.bucket),
            ),
          ),
      ],
    );
  }
}

class _BucketTasks extends ConsumerWidget {
  const _BucketTasks({
    required this.bucket,
    required this.onOpenTaskMenu,
  });

  final TaskBucket bucket;
  final void Function(BuildContext, WidgetRef, Task) onOpenTaskMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(priorityBucketTasksProvider(bucket));
    if (tasks.isEmpty) {
      return const Center(
        child: Text(
          'No tasks in this bucket.',
          style: TextStyle(color: AppColors.dim, fontStyle: FontStyle.italic),
        ),
      );
    }
    return ListView(
      padding: NxLayout.contentPadding,
      children: [
        for (final t in tasks)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TaskRow(
              task: t,
              showStatus: true,
              onMenu: () => onOpenTaskMenu(context, ref, t),
            ),
          ),
      ],
    );
  }
}
