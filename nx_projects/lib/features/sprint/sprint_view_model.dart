import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nx_projects/data/fake/seed_data.dart';
import 'package:nx_projects/data/providers.dart';
import 'package:nx_projects/domain/sprint/sprint.dart';
import 'package:nx_projects/domain/task/task.dart';
import 'package:nx_projects/domain/task/task_kind.dart';
import 'package:nx_projects/domain/task/task_severity.dart';
import 'package:nx_projects/domain/task/task_status.dart';
import 'package:nx_projects/core/formatting/date_label.dart';
import 'package:nx_projects/features/shell/selection_providers.dart';

final currentSprintProvider = Provider<Sprint>((ref) {
  final sprints = ref.watch(sprintsListProvider);
  if (sprints.isEmpty) {
    return const Sprint(
      id: 0,
      name: '…',
      dates: '—',
      badge: '—',
      start: '2000-01-01',
      length: 1,
      capH: 0,
    );
  }
  final i = ref.watch(sprintIndexProvider);
  final safeIdx =
      (i >= 0 && i < sprints.length) ? i : (sprints.length > 1 ? 1 : 0);
  return sprints[safeIdx];
});

final sprintTasksProvider = Provider<List<Task>>((ref) {
  final sp = ref.watch(currentSprintProvider);
  final tasks = ref.watch(tasksListProvider);
  return tasks.where((t) => t.sprintId == sp.id).toList();
});

class SprintDaySlice {
  const SprintDaySlice({
    required this.ymd,
    required this.tasks,
    required this.dayHours,
    required this.isToday,
    required this.isPast,
    required this.dayActual,
    required this.doneCount,
    required this.pushedCount,
    required this.rolledCount,
  });

  final String ymd;
  final List<Task> tasks;
  final double dayHours;
  final bool isToday;
  final bool isPast;
  final double dayActual;
  final int doneCount;
  final int pushedCount;
  final int rolledCount;
}

int sprintDayIndexOneBased(Sprint sp) {
  final start = parseLocalDate(sp.start);
  final today = parseLocalDate(kReferenceTodayYmd);
  var k = 1 + today.difference(start).inDays;
  if (k < 1) k = 1;
  if (k > sp.length) k = sp.length;
  return k;
}

final sprintDriftCountProvider = Provider<int>((ref) {
  return ref
      .watch(sprintTasksProvider)
      .where((t) => t.driftFrom.isNotEmpty)
      .length;
});

final sprintBlockedCountProvider = Provider<int>((ref) {
  return ref
      .watch(sprintTasksProvider)
      .where((t) => t.status == TaskStatus.blocked)
      .length;
});

final sprintDaySlicesProvider = Provider<List<SprintDaySlice>>((ref) {
  final sp = ref.watch(currentSprintProvider);
  final tasks = ref.watch(sprintTasksProvider);
  final todayYmd = kReferenceTodayYmd;
  final out = <SprintDaySlice>[];
  final start = parseLocalDate(sp.start);
  for (var i = 0; i < sp.length; i++) {
    final d = DateTime(start.year, start.month, start.day).add(Duration(days: i));
    final ymd = formatYmd(d);
    final dayTasks = tasks.where((t) => t.plannedFor == ymd).toList();
    final h = dayTasks.fold<double>(0, (a, t) => a + t.estimate);
    final actual = dayTasks.fold<double>(0, (a, t) => a + t.actualHours);
    var done = 0, pushed = 0, rolled = 0;
    for (final t in dayTasks) {
      if (t.status == TaskStatus.done) done++;
      if (t.driftFrom.isNotEmpty) rolled++;
    }
    for (final t in tasks) {
      if (t.driftFrom.contains(ymd) && t.plannedFor != ymd) {
        pushed++;
      }
    }
    final isPast = ymd.compareTo(todayYmd) < 0;
    out.add(
      SprintDaySlice(
        ymd: ymd,
        tasks: dayTasks,
        dayHours: h,
        isToday: ymd == todayYmd,
        isPast: isPast,
        dayActual: actual,
        doneCount: done,
        pushedCount: pushed,
        rolledCount: rolled,
      ),
    );
  }
  return out;
});

class SprintHeaderStats {
  const SprintHeaderStats({
    required this.totalH,
    required this.pct,
    required this.todoH,
    required this.doingH,
    required this.blockedH,
    required this.doneH,
    required this.nDoing,
    required this.nTodo,
    required this.nBlocked,
    required this.nDone,
    required this.nFeat,
    required this.nBug,
    required this.critBugs,
  });

  final double totalH;
  final int pct;
  final double todoH, doingH, blockedH, doneH;
  final int nDoing, nTodo, nBlocked, nDone, nFeat, nBug, critBugs;
}

final sprintHeaderStatsProvider = Provider<SprintHeaderStats>((ref) {
  final sp = ref.watch(currentSprintProvider);
  final items = ref.watch(sprintTasksProvider);
  var todoH = 0.0, doingH = 0.0, blockedH = 0.0, doneH = 0.0;
  var nTodo = 0, nDoing = 0, nBlocked = 0, nDone = 0, nFeat = 0, nBug = 0, critBugs = 0;
  for (final t in items) {
    if (t.status == TaskStatus.todo) {
      nTodo++;
      todoH += t.estimate;
    } else if (t.status == TaskStatus.doing) {
      nDoing++;
      doingH += t.estimate;
    } else if (t.status == TaskStatus.blocked) {
      nBlocked++;
      blockedH += t.estimate;
    } else {
      nDone++;
      doneH += t.estimate;
    }
    if (t.kind == TaskKind.feat) nFeat++;
    if (t.kind == TaskKind.bug) {
      nBug++;
      if (t.severity == TaskSeverity.crit) critBugs++;
    }
  }
  final totalH = items.fold<double>(0, (a, t) => a + t.estimate);
  final pct = sp.capH > 0 ? ((totalH / sp.capH) * 100).round().clamp(0, 100) : 0;
  return SprintHeaderStats(
    totalH: totalH,
    pct: pct,
    todoH: todoH,
    doingH: doingH,
    blockedH: blockedH,
    doneH: doneH,
    nDoing: nDoing,
    nTodo: nTodo,
    nBlocked: nBlocked,
    nDone: nDone,
    nFeat: nFeat,
    nBug: nBug,
    critBugs: critBugs,
  );
});
