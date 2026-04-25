import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nx_projects/data/providers.dart';
import 'package:nx_projects/domain/task/task.dart';
import 'package:nx_projects/domain/task/task_kind.dart';
import 'package:nx_projects/domain/task/task_severity.dart';
import 'package:nx_projects/domain/task/task_status.dart';
import 'package:nx_projects/core/formatting/date_label.dart';
import 'package:nx_projects/features/shell/selection_providers.dart';

final dailyTasksProvider = Provider<List<Task>>((ref) {
  final ymd = ref.watch(dailyDateProvider);
  final tasks = ref.watch(tasksListProvider);
  return tasks.where((t) => t.plannedFor == ymd).toList()..sort((a, b) {
        const order = {
          TaskStatus.doing: 0,
          TaskStatus.todo: 1,
          TaskStatus.blocked: 2,
          TaskStatus.done: 3,
        };
        return (order[a.status] ?? 9).compareTo(order[b.status] ?? 9);
      });
});

class DailyHeaderStats {
  const DailyHeaderStats({
    required this.totalEst,
    required this.hTodo,
    required this.hDoing,
    required this.hBlocked,
    required this.hDone,
    required this.pct,
    required this.nDoing,
    required this.nTodo,
    required this.nBlocked,
    required this.nDone,
    required this.nFeat,
    required this.nBug,
    required this.critBugs,
  });

  final double totalEst;
  final double hTodo, hDoing, hBlocked, hDone;
  final int pct;
  final int nDoing, nTodo, nBlocked, nDone, nFeat, nBug, critBugs;
}

final dailyHeaderStatsProvider = Provider<DailyHeaderStats>((ref) {
  final todays = ref.watch(dailyTasksProvider);
  var hTodo = 0.0, hDoing = 0.0, hBlocked = 0.0, hDone = 0.0;
  var nTodo = 0, nDoing = 0, nBlocked = 0, nDone = 0, nFeat = 0, nBug = 0, critBugs = 0;
  for (final t in todays) {
    if (t.status == TaskStatus.todo) {
      nTodo++;
      hTodo += t.estimate;
    } else if (t.status == TaskStatus.doing) {
      nDoing++;
      hDoing += t.estimate;
    } else if (t.status == TaskStatus.blocked) {
      nBlocked++;
      hBlocked += t.estimate;
    } else {
      nDone++;
      hDone += t.estimate;
    }
    if (t.kind == TaskKind.feat) nFeat++;
    if (t.kind == TaskKind.bug) {
      nBug++;
      if (t.severity == TaskSeverity.crit) critBugs++;
    }
  }
  final totalEst = todays.fold<double>(0, (a, t) => a + t.estimate);
  final pct = totalEst > 0 ? ((hDone / totalEst) * 100).round() : 0;
  return DailyHeaderStats(
    totalEst: totalEst,
    hTodo: hTodo,
    hDoing: hDoing,
    hBlocked: hBlocked,
    hDone: hDone,
    pct: pct,
    nDoing: nDoing,
    nTodo: nTodo,
    nBlocked: nBlocked,
    nDone: nDone,
    nFeat: nFeat,
    nBug: nBug,
    critBugs: critBugs,
  );
});

/// Helper: parse daily date
DateTime dailyDateTime(Ref ref) {
  return parseLocalDate(ref.watch(dailyDateProvider));
}
