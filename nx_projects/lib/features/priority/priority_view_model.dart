import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nx_projects/data/providers.dart';
import 'package:nx_projects/domain/task/task.dart';
import 'package:nx_projects/domain/task/task_bucket.dart';
import 'package:nx_projects/features/filters/filter_state_providers.dart';

class BucketSummary {
  const BucketSummary({
    required this.bucket,
    required this.count,
    required this.hours,
  });

  final TaskBucket bucket;
  final int count;
  final double hours;
}

bool _matchQuery(Task t, String q) {
  if (q.isEmpty) return true;
  return t.title.toLowerCase().contains(q) || t.crumb.toLowerCase().contains(q);
}

final priorityBucketsProvider = Provider<List<BucketSummary>>((ref) {
  final tasks = ref.watch(tasksListProvider);
  final q = ref.watch(searchQueryProvider).trim().toLowerCase();
  final filtered = tasks.where((t) => _matchQuery(t, q)).toList();
  final buckets = <TaskBucket>[
    TaskBucket.now,
    TaskBucket.next,
    TaskBucket.later,
    TaskBucket.someday,
  ];
  return [
    for (final b in buckets)
      () {
        final items = filtered.where((t) => t.bucket == b);
        return BucketSummary(
          bucket: b,
          count: items.length,
          hours: items.fold<double>(0, (a, t) => a + t.estimate),
        );
      }(),
    BucketSummary(
      bucket: TaskBucket.unsorted,
      count: filtered.where((t) => t.bucket == TaskBucket.unsorted).length,
      hours: filtered
          .where((t) => t.bucket == TaskBucket.unsorted)
          .fold<double>(0, (a, t) => a + t.estimate),
    ),
  ];
});

final priorityBucketTasksProvider = Provider.family<List<Task>, TaskBucket>((
  ref,
  bucket,
) {
  final tasks = ref.watch(tasksListProvider);
  final q = ref.watch(searchQueryProvider).trim().toLowerCase();
  return tasks.where((t) {
    final inBucket = bucket == TaskBucket.unsorted
        ? t.bucket == TaskBucket.unsorted
        : t.bucket == bucket;
    return inBucket && _matchQuery(t, q);
  }).toList();
});
