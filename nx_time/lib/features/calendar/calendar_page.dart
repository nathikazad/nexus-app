import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nx_time/core/widgets/nx_tab_header.dart';
import 'package:nx_time/domain/calendar/calendar_entry.dart';
import 'package:nx_time/features/calendar/calendar_feed_providers.dart';
import 'package:nx_time/features/calendar/calendar_record_editor.dart';
import 'package:nx_time/features/tasks/task_detail_page.dart';

/// The planning calendar has its own week, independent of history and goals.
final planningWeekProvider = NotifierProvider<PlanningWeek, DateTime>(
  PlanningWeek.new,
);

class PlanningWeek extends Notifier<DateTime> {
  @override
  DateTime build() => monday(DateTime.now());
  static DateTime monday(DateTime d) =>
      DateTime(d.year, d.month, d.day - d.weekday + 1);
  void move(int days) =>
      state = DateTime(state.year, state.month, state.day + days);
  void today() => state = monday(DateTime.now());
}

final planningFeedProvider = FutureProvider.autoDispose<CalendarFeed>((
  ref,
) async {
  final repo = await ref.watch(calendarRepositoryProvider.future);
  final week = ref.watch(planningWeekProvider);
  return repo.load(week, DateTime(week.year, week.month, week.day + 7));
});

/// Remaining tasks, independent events/birthdays and explicit plans only.
bool isPlanningEntry(CalendarEntry e) {
  if (e.isTask)
    return e.kind != 'completion' &&
        ['todo', 'progress'].contains(e.status ?? 'todo');
  if (e.kind == 'event' || e.kind == 'birthday') return true;
  return e.kind == 'action' && e.status == 'planned';
}

class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});
  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  int? selectedDay;
  Future<void> open([CalendarEntry? entry]) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => entry?.isTask == true
            ? TaskDetailPage(taskId: entry!.id)
            : CalendarRecordEditor(entry: entry),
      ),
    );
    ref.invalidate(planningFeedProvider);
  }

  @override
  Widget build(BuildContext context) {
    final week = ref.watch(planningWeekProvider);
    final feed = ref.watch(planningFeedProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = List.generate(
      7,
      (i) => DateTime(week.year, week.month, week.day + i),
    );
    return Column(
      children: [
        const NxTabHeader(title: 'Calendar'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Previous week',
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  ref.read(planningWeekProvider.notifier).move(-7);
                  setState(() => selectedDay = null);
                },
              ),
              Expanded(
                child: Text(
                  '${DateFormat.MMMd().format(week)} – ${DateFormat.MMMd().format(days.last)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  ref.read(planningWeekProvider.notifier).today();
                  setState(() => selectedDay = null);
                },
                child: const Text('Today'),
              ),
              IconButton(
                tooltip: 'Next week',
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  ref.read(planningWeekProvider.notifier).move(7);
                  setState(() => selectedDay = null);
                },
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: InkWell(
                    onTap: () => setState(
                      () => selectedDay = selectedDay == i ? null : i,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: selectedDay == i
                            ? const Color(0xFFE0F5F2)
                            : null,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          Text(
                            DateFormat.E().format(days[i]).substring(0, 1),
                            style: const TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: days[i] == today
                                ? const Color(0xFF007F73)
                                : Colors.transparent,
                            child: Text(
                              '${days[i].day}',
                              style: TextStyle(
                                color: days[i] == today
                                    ? Colors.white
                                    : Colors.black87,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  selectedDay == null
                      ? 'Your plans this week'
                      : DateFormat('EEEE, MMM d').format(days[selectedDay!]),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              if (selectedDay != null)
                TextButton(
                  onPressed: () => setState(() => selectedDay = null),
                  child: const Text('Whole week'),
                ),
              IconButton(
                tooltip: 'Refresh plans',
                onPressed: () => ref.invalidate(planningFeedProvider),
                icon: const Icon(Icons.refresh, size: 20),
              ),
              IconButton(
                tooltip: 'Add plan',
                onPressed: () => open(),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: feed.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Could not load plans: $e')),
            data: (f) {
              final entries = f.entries.where(isPlanningEntry).toList();
              final overdue = f.currentTasks.where((e) {
                final due = e.time('due_at');
                return due != null && due.isBefore(week) && due.isBefore(today);
              }).toList();
              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(planningFeedProvider);
                  await ref.read(planningFeedProvider.future);
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    if (overdue.isNotEmpty)
                      ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                        leading: const Icon(
                          Icons.pending_actions,
                          color: Colors.orange,
                        ),
                        title: Text(
                          '${overdue.length} overdue ${overdue.length == 1 ? 'task' : 'tasks'}',
                        ),
                        subtitle: const Text(
                          'Still open from before this week',
                        ),
                        children: [
                          for (final e in overdue)
                            ListTile(
                              title: Text(e.name),
                              subtitle: Text(
                                'Due ${DateFormat.MMMd().format(e.time('due_at')!)}',
                              ),
                              onTap: () => open(e),
                            ),
                        ],
                      ),
                    for (var i = 0; i < 7; i++)
                      if (selectedDay == null || selectedDay == i) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
                          child: Text(
                            '${days[i] == today ? 'Today · ' : ''}${DateFormat('EEEE, MMM d').format(days[i])}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (!entries.any((e) => e.occursOn(days[i])))
                          const Padding(
                            padding: EdgeInsets.fromLTRB(68, 8, 0, 12),
                            child: Text(
                              'No plans',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        for (final e in entries.where(
                          (e) => e.occursOn(days[i]),
                        ))
                          _entry(e),
                      ],
                    if (f.unscheduled.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 24),
                        child: Text(
                          '${f.unscheduled.length} unscheduled tasks are in your Tasks tab.',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _entry(CalendarEntry e) {
    final color = e.isTask
        ? const Color(0xFF007F73)
        : e.kind == 'birthday'
        ? const Color(0xFFAD5B16)
        : e.kind == 'event'
        ? const Color(0xFF6750A4)
        : const Color(0xFF2463BD);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(
                e.kind == 'birthday'
                    ? 'Birthday'
                    : e.start == null
                    ? ''
                    : DateFormat('h:mm a').format(e.start!),
                style: const TextStyle(fontSize: 11, color: Colors.black54),
              ),
            ),
          ),
          Expanded(
            child: Ink(
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.07),
                border: Border(left: BorderSide(color: color, width: 3)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  ListTile(
                    dense: true,
                    title: Text(
                      e.kind == 'birthday' ? '${e.name}’s birthday' : e.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      [
                        if (e.isTask)
                          e.status == 'progress' ? 'In progress' : 'To do',
                        if (e.kind == 'action') 'Planned',
                        if (e.kind == 'event')
                          e.attendance.isEmpty
                              ? 'Event · attendance not planned'
                              : 'Event · ${e.attendance.first.status}',
                        if (e.end != null)
                          'Until ${DateFormat('h:mm a').format(e.end!)}',
                        ...e.links
                            .where(
                              (l) =>
                                  ['Person', 'Place'].contains(l['model_type']),
                            )
                            .map((l) => l['name'].toString()),
                      ].join(' · '),
                    ),
                    onTap: () => open(e),
                  ),
                  for (final a in e.attendance)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.person_outline, size: 18),
                      title: Text('Attendance: ${a.status}'),
                      onTap: () => open(a),
                    ),
                  if (e.kind == 'event' && e.attendance.isEmpty)
                    TextButton(
                      onPressed: () async {
                        try {
                          final repo = await ref.read(
                            calendarRepositoryProvider.future,
                          );
                          await repo.planAttendance(e);
                          ref.invalidate(planningFeedProvider);
                        } catch (err) {
                          if (mounted)
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(SnackBar(content: Text('$err')));
                        }
                      },
                      child: const Text('Plan to go'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
