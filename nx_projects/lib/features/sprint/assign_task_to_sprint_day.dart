import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nx_projects/data/providers.dart';
import 'package:nx_projects/domain/sprint/sprint.dart';
import 'package:nx_projects/domain/task/task.dart';

Future<void> assignTaskToSprintDay({
  required WidgetRef ref,
  required Task task,
  required Sprint sprint,
  required String? ymd,
}) async {
  if (task.sprintId != sprint.id) {
    throw StateError('Task ${task.id} is not in sprint ${sprint.id}');
  }

  final cur = await ref.read(taskRepositoryProvider).getById(task.id) ?? task;
  if (cur.plannedFor == ymd) return;

  var drift = List<String>.from(cur.driftFrom);
  final old = cur.plannedFor;
  if (old != null &&
      old.isNotEmpty &&
      ymd != null &&
      old != ymd &&
      !drift.contains(old)) {
    drift = [...drift, old];
    if (drift.length > 5) {
      drift = drift.sublist(drift.length - 5);
    }
  }

  await ref
      .read(taskRepositoryProvider)
      .upsert(
        cur.copyWith(
          plannedFor: ymd,
          clearPlannedFor: ymd == null,
          driftFrom: drift,
        ),
      );
  ref.invalidate(tasksListAsyncProvider);
}
