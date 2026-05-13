import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nx_time/data/providers.dart';
import 'package:nx_time/domain/tasks/task.dart';
import 'package:nx_time/domain/tasks/task_repository.dart';
import 'package:nx_time/domain/tasks/task_status.dart';
import 'package:nx_time/features/tasks/task_view_models.dart';

const _pickerRecentLimit = 20;

/// Tasks on [day] that are not [TaskStatus.done].
Future<List<Task>> unfinishedTasksOnDay(
  TaskRepository repo,
  DateTime day,
) async {
  final list = await repo.listAll(onDate: calendarDay(day));
  return list.where((t) => t.status != TaskStatus.done).toList()
    ..sort((a, b) => a.name.compareTo(b.name));
}

final pickerUnfinishedYesterdayProvider = FutureProvider<List<Task>>((
  ref,
) async {
  await ref.watch(authenticatedUserProvider.future);
  final repo = ref.read(taskRepositoryProvider);
  final y = calendarDay(DateTime.now()).subtract(const Duration(days: 1));
  return unfinishedTasksOnDay(repo, y);
});

final pickerRecentTasksProvider = FutureProvider<List<Task>>((ref) async {
  await ref.watch(authenticatedUserProvider.future);
  final all = await ref.read(taskRepositoryProvider).listAll();
  final sorted = List<Task>.from(all)..sort((a, b) => b.id.compareTo(a.id));
  if (sorted.length <= _pickerRecentLimit) return sorted;
  return sorted.sublist(0, _pickerRecentLimit);
});
