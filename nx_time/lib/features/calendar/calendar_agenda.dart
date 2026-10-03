import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nx_time/domain/calendar/calendar_entry.dart';
import 'package:nx_time/features/calendar/calendar_feed_providers.dart';
import 'package:nx_time/features/calendar/calendar_record_editor.dart';
import 'package:nx_time/features/tasks/task_detail_page.dart';

class CalendarAgenda extends ConsumerWidget {
  const CalendarAgenda({super.key, required this.day, this.tasksOnly = false});
  final DateTime day;
  final bool tasksOnly;
  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    CalendarEntry e,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => e.isTask
            ? TaskDetailPage(taskId: e.id)
            : CalendarRecordEditor(entry: e),
      ),
    );
    ref.invalidate(calendarFeedProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(calendarFeedProvider);
    final actual = ref.watch(calendarHistoryProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(actual ? 'Actual history' : 'Schedule'),
                  value: actual,
                  onChanged: (v) =>
                      ref.read(calendarHistoryProvider.notifier).set(v),
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: () => ref.invalidate(calendarFeedProvider),
                icon: const Icon(Icons.refresh),
              ),
              IconButton(
                tooltip: 'Add calendar item',
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => CalendarRecordEditor(
                        initialType: tasksOnly ? 'Task' : 'Event',
                      ),
                    ),
                  );
                  ref.invalidate(calendarFeedProvider);
                },
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ),
        Expanded(
          child: feed.when(
            data: (f) {
              final entries = f.entries
                  .where((e) => e.occursOn(day) && (!tasksOnly || e.isTask))
                  .toList();
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                children: [
                  if (entries.isEmpty)
                    const ListTile(
                      title: Text('Nothing scheduled for this day'),
                    ),
                  for (final group in groupCalendarEntries(entries))
                    for (final e in [group.entry])
                      Card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ListTile(
                              onTap: () => _open(context, ref, e),
                              leading: Icon(
                                e.kind == 'birthday'
                                    ? Icons.cake
                                    : e.isTask
                                    ? Icons.check_circle_outline
                                    : e.kind == 'event'
                                    ? Icons.event
                                    : Icons.people_outline,
                              ),
                              title: Text(
                                e.kind == 'birthday'
                                    ? "${e.name}’s birthday"
                                    : e.name,
                              ),
                              subtitle: Text(
                                [
                                  e.kind == 'birthday'
                                      ? 'Birthday'
                                      : '${e.kind == 'deadline'
                                            ? 'Due · '
                                            : e.kind == 'completion'
                                            ? 'Completed · '
                                            : ''}${e.start == null ? '' : DateFormat.jm().format(e.start!)}${e.end == null ? '' : ' – ${DateFormat.jm().format(e.end!)}'}',
                                  if (e.status != null) e.status!,
                                  if (e.description?.isNotEmpty ?? false)
                                    e.description!,
                                  for (final l in e.links)
                                    '${l['model_type']}: ${l['name']}',
                                ].join('\n'),
                              ),
                            ),
                            for (final child in group.descendants)
                              ListTile(
                                contentPadding: const EdgeInsets.only(
                                  left: 40,
                                  right: 16,
                                ),
                                title: Text(child.name),
                                subtitle: Text(child.status ?? child.modelType),
                                leading: const Icon(
                                  Icons.subdirectory_arrow_right,
                                ),
                                onTap: () => _open(context, ref, child),
                              ),
                            for (final a in e.attendance)
                              ListTile(
                                title: Text(
                                  'Your attendance: ${a.status ?? 'not recorded'}',
                                ),
                                subtitle: Text(
                                  [
                                    if (a.time('scheduled_start_time') != null)
                                      'Planned: ${DateFormat('MMM d, h:mm a').format(a.time('scheduled_start_time')!)}',
                                    if (a.time('start_time') != null)
                                      'Actual: ${DateFormat('MMM d, h:mm a').format(a.time('start_time')!)}',
                                  ].join('\n'),
                                ),
                                trailing: const Icon(Icons.edit),
                                onTap: () => _open(context, ref, a),
                              ),
                            if (e.kind == 'event' && e.attendance.isEmpty)
                              Align(
                                alignment: Alignment.centerRight,
                                child: _PlanAttendanceButton(event: e),
                              ),
                          ],
                        ),
                      ),
                  if (f.unscheduled.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'Unscheduled tasks',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    for (final e in f.unscheduled)
                      ListTile(
                        title: Text(e.name),
                        onTap: () => _open(context, ref, e),
                      ),
                  ],
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Could not load calendar: $e')),
          ),
        ),
      ],
    );
  }
}

class _PlanAttendanceButton extends ConsumerStatefulWidget {
  const _PlanAttendanceButton({required this.event});
  final CalendarEntry event;
  @override
  ConsumerState<_PlanAttendanceButton> createState() =>
      _PlanAttendanceButtonState();
}

class _PlanAttendanceButtonState extends ConsumerState<_PlanAttendanceButton> {
  bool busy = false;
  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: busy
        ? null
        : () async {
            setState(() => busy = true);
            try {
              final repo = await ref.read(calendarRepositoryProvider.future);
              await repo.planAttendance(widget.event);
              ref.invalidate(calendarFeedProvider);
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(e.toString())));
              }
            } finally {
              if (mounted) setState(() => busy = false);
            }
          },
    child: Text(busy ? 'Saving…' : 'Plan to go'),
  );
}
