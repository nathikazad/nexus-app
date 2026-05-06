import 'package:nx_projects/core/formatting/date_label.dart';
import 'package:nx_projects/domain/task/task.dart';

double workLinkActualHours(TaskWorkLink link) {
  final attrHours = link.timeSpentHours;
  if (attrHours != null && attrHours > 0) return attrHours;

  final start = link.startTime;
  final end = link.endTime;
  if (start == null || end == null || !end.isAfter(start)) return 0;
  return end.difference(start).inMinutes / 60.0;
}

double taskActualHoursForDay(Task task, String ymd) {
  return taskWorkLinksForDay(
    task,
    ymd,
  ).fold<double>(0, (total, link) => total + workLinkActualHours(link));
}

List<TaskWorkLink> taskWorkLinksForDay(Task task, String ymd) {
  final out = <TaskWorkLink>[];
  for (final link in task.workLinks) {
    final start = link.startTime;
    if (start == null || formatYmd(start) != ymd) continue;
    out.add(link);
  }
  out.sort((a, b) {
    final at = a.startTime;
    final bt = b.startTime;
    if (at == null && bt == null) {
      return a.workActionName.compareTo(b.workActionName);
    }
    if (at == null) return 1;
    if (bt == null) return -1;
    return at.compareTo(bt);
  });
  return out;
}

double tasksActualHoursForDay(Iterable<Task> tasks, String ymd) {
  return tasks.fold<double>(
    0,
    (total, task) => total + taskActualHoursForDay(task, ymd),
  );
}
