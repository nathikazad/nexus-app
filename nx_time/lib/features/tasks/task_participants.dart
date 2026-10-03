import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_time/data/domains/domain_workspace.dart';
import 'package:nx_time/domain/tasks/task.dart';
import 'package:nx_time/data/tasks/task_settings.dart';
export 'package:nx_time/data/tasks/task_settings.dart';

class TaskAssignment extends ConsumerWidget {
  const TaskAssignment({super.key, required this.task, this.compact = false});
  final Task task;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(timeDomainsProvider).asData?.value;
    final domainId = workspace?.origins[task.id];
    if (workspace == null ||
        domainId == null ||
        domainId == workspace.personalId)
      return const SizedBox.shrink();
    final members = ref.watch(taskDomainMembersProvider(domainId));
    return members.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(8),
        child: Text('Loading assignment…', style: TextStyle(fontSize: 12)),
      ),
      error: (error, _) => TextButton(
        onPressed: () => ref.invalidate(taskDomainMembersProvider(domainId)),
        child: const Text('Retry assignment'),
      ),
      data: (names) {
        final assigned = task.participants.entries
            .where((e) => e.value is Map && e.value['assigned'] == true)
            .map((e) => e.key)
            .toSet();
        final label = assigned.isEmpty
            ? 'Unassigned'
            : assigned.map((id) => names[id] ?? 'Former member').join(', ');
        if (compact) {
          return Row(
            children: [
              const Icon(
                Icons.person_outline_rounded,
                size: 13,
                color: Color(0xFF94A3B8),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ),
            ],
          );
        }
        return TextButton.icon(
          style: TextButton.styleFrom(
            foregroundColor: Colors.blueGrey,
            textStyle: TextStyle(fontSize: compact ? 11 : 13),
          ),
          icon: Icon(Icons.person_outline_rounded, size: compact ? 15 : 18),
          label: Text(compact ? label : 'Assigned to: $label'),
          onPressed: !workspace.canWriteModel(task.id)
              ? null
              : () async {
                  final selected = await showDialog<Set<String>>(
                    context: context,
                    builder: (context) =>
                        _AssignmentDialog(names: names, assigned: assigned),
                  );
                  if (selected == null || !context.mounted) return;
                  final patch = <String, dynamic>{
                    for (final id in names.keys)
                      if (selected.contains(id) != assigned.contains(id))
                        id: {'assigned': selected.contains(id)},
                  };
                  if (patch.isEmpty) return;
                  try {
                    await patchTaskSettings(ref, task, {'participants': patch});
                  } catch (e) {
                    if (context.mounted)
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Could not save assignment: $e'),
                        ),
                      );
                  }
                },
        );
      },
    );
  }
}

class _AssignmentDialog extends StatefulWidget {
  const _AssignmentDialog({required this.names, required this.assigned});
  final Map<String, String> names;
  final Set<String> assigned;
  @override
  State<_AssignmentDialog> createState() => _AssignmentDialogState();
}

class _AssignmentDialogState extends State<_AssignmentDialog> {
  late final selected = {...widget.assigned};
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Assigned to'),
    content: SizedBox(
      width: 320,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final member in widget.names.entries)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(member.value),
                value: selected.contains(member.key),
                onChanged: (value) => setState(() {
                  if (value == true) {
                    selected.add(member.key);
                  } else {
                    selected.remove(member.key);
                  }
                }),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context, selected),
        child: const Text('Save'),
      ),
    ],
  );
}
