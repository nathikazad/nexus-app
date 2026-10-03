import 'package:nx_time/data/providers.dart';
import 'package:nx_time/data/action/planning_schema.dart';
import 'package:nx_time/domain/calendar/birthday.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/kgql.dart';
import 'package:nx_time/domain/calendar/calendar_entry.dart';
import 'package:nx_time/features/calendar/calendar_datetime_field.dart';
import 'package:nx_time/features/calendar/calendar_feed_providers.dart';
import 'package:nx_time/features/calendar/calendar_providers.dart';
import 'package:nx_time/features/tasks/task_view_models.dart';

class CalendarRecordEditor extends ConsumerStatefulWidget {
  const CalendarRecordEditor({
    super.key,
    this.entry,
    this.initialType = 'Event',
  });
  final CalendarEntry? entry;
  final String initialType;
  @override
  ConsumerState<CalendarRecordEditor> createState() =>
      _CalendarRecordEditorState();
}

class _CalendarRecordEditorState extends ConsumerState<CalendarRecordEditor> {
  late final TextEditingController name, notes, birthday;
  late String type, status;
  DateTime? start, end, actualStart, actualEnd, due;
  int? personId, placeId;
  bool saving = false;
  String? error;
  List<Model> people = [], places = [];
  Set<String> plannableTypes = {};
  bool schemaReady = false;
  bool get action =>
      plannableTypes.contains(type) ||
      widget.entry?.attributes.containsKey('planning_status') == true;
  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    type = e?.modelType ?? widget.initialType;
    name = TextEditingController(text: e?.name ?? '');
    notes = TextEditingController(text: e?.description ?? '');
    birthday = TextEditingController(
      text: e?.attributes['birthday']?.toString() ?? '',
    );
    status = e?.status ?? (type == 'Task' ? 'todo' : 'planned');
    start = e?.time(action ? 'scheduled_start_time' : 'start_time');
    end = e?.time(action ? 'scheduled_end_time' : 'end_time');
    actualStart = e?.time('start_time');
    actualEnd = e?.time('end_time');
    due = e?.time('due_at');
    _loadChoices();
  }

  Future<void> _loadChoices() async {
    try {
      final schema = await ref.read(actionSchemaProvider.future);
      if (!mounted) return;
      setState(() {
        plannableTypes = plannableTypeNames(schema);
        schemaReady = true;
        final e = widget.entry;
        start = e?.time(action ? "scheduled_start_time" : "start_time");
        end = e?.time(action ? "scheduled_end_time" : "end_time");
      });
      final repo = await ref.read(calendarRepositoryProvider.future);
      final results = await Future.wait([
        repo.choices('Person'),
        repo.choices('Place'),
      ]);
      if (mounted) {
        setState(() {
          people = results[0];
          places = results[1];
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  @override
  void dispose() {
    name.dispose();
    notes.dispose();
    birthday.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (saving) return;
    if (name.text.trim().isEmpty) {
      setState(() => error = 'Enter a name');
      return;
    }
    if ((start != null && end != null && end!.isBefore(start!)) ||
        (actualStart != null &&
            actualEnd != null &&
            actualEnd!.isBefore(actualStart!))) {
      setState(() => error = 'End must follow start');
      return;
    }
    if (type == 'Person' &&
        birthday.text.isNotEmpty &&
        !validBirthday(birthday.text.trim())) {
      setState(() => error = 'Use YYYY-MM-DD or --MM-DD, with a valid date');
      return;
    }
    if (action && status == 'attended' && actualStart == null) {
      setState(
        () => error = 'Enter the actual start time to record attendance',
      );
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final repo = await ref.read(calendarRepositoryProvider.future);
      final attrs = <String, dynamic>{
        if (type == 'Person')
          'birthday': birthday.text.trim().isEmpty
              ? null
              : birthday.text.trim(),
        if (type == 'Task') ...{
          'status': status,
          if (status == 'done')
            'completed_at': DateTime.now().toIso8601String(),
          'due_at': due?.toIso8601String(),
        },
        if (type != 'Person' && type != 'Task') ...{
          action ? 'scheduled_start_time' : 'start_time': start
              ?.toIso8601String(),
          action ? 'scheduled_end_time' : 'end_time': end?.toIso8601String(),
        },
        if (action) ...{
          'planning_status': status,
          'start_time': actualStart?.toIso8601String(),
          'end_time': actualEnd?.toIso8601String(),
        },
      };
      await repo.save(
        id: widget.entry?.id ?? (type == 'Person' ? personId : null),
        modelType: widget.entry == null ? type : null,
        name: name.text.trim(),
        description: notes.text,
        attributes: attrs,
        relations: [
          if (widget.entry == null && type == 'Meet' && personId != null)
            ModelRelation(
              modelType: 'Person',
              relationName: 'with_person',
              link: [personId],
            ),
          if (widget.entry == null &&
              placeId != null &&
              ['Meet', 'Event', 'Goto'].contains(type))
            ModelRelation(
              modelType: 'Place',
              relationName: type == 'Goto' ? 'to_place' : 'at_place',
              link: [placeId],
            ),
        ],
      );
      ref.invalidate(calendarFeedProvider);
      ref.invalidate(allTasksProvider);
      ref.invalidate(tasksForTodayProvider);
      invalidateActionsAfterMutation(ref);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.entry == null ? 'New $type' : 'Edit $type'),
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (widget.entry == null)
          DropdownButtonFormField<String>(
            initialValue: type,
            items: [
              for (final t in {
                'Event',
                'Task',
                'Person',
                type,
                ...plannableTypes,
              })
                DropdownMenuItem(
                  value: t,
                  child: Text(t == 'Person' ? 'Birthday' : t),
                ),
            ],
            onChanged: saving
                ? null
                : (v) => setState(() {
                    type = v!;
                    status = type == 'Task' ? 'todo' : 'planned';
                  }),
          ),
        if (widget.entry == null && ['Meet', 'Person'].contains(type))
          DropdownButtonFormField<int>(
            decoration: InputDecoration(
              labelText: type == 'Person'
                  ? 'Existing person (or enter a new name)'
                  : 'Meeting with',
            ),
            items: [
              for (final p in people)
                DropdownMenuItem(value: p.id, child: Text(p.name)),
            ],
            onChanged: (v) => setState(() {
              personId = v;
              if (type == 'Person' && v != null) {
                final p = people.firstWhere((p) => p.id == v);
                name.text = p.name;
                notes.text = p.description ?? '';
                birthday.text = p.attrString('birthday') ?? '';
              }
            }),
          ),
        TextField(
          controller: name,
          decoration: InputDecoration(
            labelText: type == 'Person' ? 'Person name' : 'Name',
          ),
        ),
        TextField(
          controller: notes,
          decoration: const InputDecoration(labelText: 'Notes'),
          minLines: 2,
          maxLines: 6,
        ),
        if (type == 'Person')
          TextField(
            controller: birthday,
            decoration: const InputDecoration(
              labelText: 'Birthday',
              hintText: '1990-05-14 or --05-14',
            ),
          ),
        if (widget.entry == null && ['Meet', 'Event'].contains(type))
          DropdownButtonFormField<int>(
            decoration: const InputDecoration(labelText: 'Place'),
            items: [
              for (final p in places)
                DropdownMenuItem(value: p.id, child: Text(p.name)),
            ],
            onChanged: (v) => placeId = v,
          ),
        if (widget.entry != null)
          for (final l in widget.entry!.links)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l['name']?.toString() ?? ''),
              subtitle: Text(l['relation_name']?.toString() ?? ''),
            ),
        if (type != 'Person' && type != 'Task') ...[
          CalendarDateTimeField(
            label: action ? 'Scheduled start' : 'Start',
            value: start,
            onChanged: (v) => setState(() => start = v),
          ),
          CalendarDateTimeField(
            label: action ? 'Scheduled end' : 'End',
            value: end,
            onChanged: (v) => setState(() => end = v),
          ),
        ],
        if (type == 'Task')
          CalendarDateTimeField(
            label: 'Due',
            value: due,
            onChanged: (v) => setState(() => due = v),
          ),
        if (action || type == 'Task')
          DropdownButtonFormField<String>(
            key: ValueKey(type),
            initialValue: status,
            decoration: const InputDecoration(labelText: 'Status'),
            items: [
              for (final s
                  in type == 'Task'
                      ? ['todo', 'progress', 'done', 'skip']
                      : ['planned', 'attended', 'skipped', 'cancelled'])
                DropdownMenuItem(value: s, child: Text(s)),
            ],
            onChanged: (v) => setState(() => status = v!),
          ),
        if (action) ...[
          CalendarDateTimeField(
            label: 'Actual start',
            value: actualStart,
            onChanged: (v) => setState(() => actualStart = v),
          ),
          CalendarDateTimeField(
            label: 'Actual end',
            value: actualEnd,
            onChanged: (v) => setState(() => actualEnd = v),
          ),
        ],
        if (error != null)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: saving || !schemaReady ? null : save,
          child: Text(saving ? 'Saving…' : 'Save'),
        ),
      ],
    ),
  );
}
