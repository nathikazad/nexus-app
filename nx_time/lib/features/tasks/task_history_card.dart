import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nx_time/core/theme/app_theme.dart';

/// A compact, newest-first timeline of the task's recorded changes.
class TaskHistoryCard extends StatelessWidget {
  const TaskHistoryCard({super.key, required this.history});

  final List<Map<String, dynamic>> history;

  @override
  Widget build(BuildContext context) {
    final entries = history.reversed.toList();
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.slate50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.slate100),
      ),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        iconColor: AppColors.slate500,
        collapsedIconColor: AppColors.slate400,
        leading: const Icon(
          Icons.history_rounded,
          size: 21,
          color: AppColors.slate500,
        ),
        title: const Text(
          'Task history',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.slate900,
          ),
        ),
        subtitle: Text(
          '${entries.length} ${entries.length == 1 ? 'update' : 'updates'} · Latest first',
          style: const TextStyle(fontSize: 11, color: AppColors.slate500),
        ),
        children: [
          for (var i = 0; i < entries.length; i++)
            _HistoryEntry(entry: entries[i], last: i == entries.length - 1),
        ],
      ),
    );
  }
}

class _HistoryEntry extends StatelessWidget {
  const _HistoryEntry({required this.entry, required this.last});
  final Map<String, dynamic> entry;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final raw = entry['status']?.toString() ?? '';
    final (label, icon, color) = switch (raw) {
      'todo' => (
        'To do',
        Icons.radio_button_unchecked_rounded,
        const Color(0xFF5275A5),
      ),
      'progress' || 'in_progress' => (
        'In progress',
        Icons.play_arrow_rounded,
        const Color(0xFFB48148),
      ),
      'done' || 'completed' => (
        'Completed',
        Icons.check_rounded,
        const Color(0xFF398477),
      ),
      'skip' ||
      'skipped' => ('Skipped', Icons.skip_next_rounded, AppColors.slate500),
      _ => (
        raw.isEmpty ? 'Updated' : raw.replaceAll('_', ' '),
        Icons.edit_outlined,
        AppColors.slate500,
      ),
    };
    final at = DateTime.tryParse(entry['at']?.toString() ?? '')?.toLocal();
    final due = DateTime.tryParse(entry['due_at']?.toString() ?? '')?.toLocal();
    final note = entry['note']?.toString().trim() ?? '';
    String formatDue(DateTime value) => DateFormat(
      value.hour == 0 && value.minute == 0
          ? 'MMM d, yyyy'
          : 'MMM d, yyyy · h:mm a',
    ).format(value);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
                if (!last)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Container(width: 1, color: AppColors.slate200),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.slate900,
                    ),
                  ),
                  if (at != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      DateFormat('MMM d, yyyy · h:mm a').format(at),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.slate500,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    entry['due_at'] == null
                        ? 'No due date'
                        : due == null
                        ? 'Due date unavailable'
                        : 'Due ${formatDue(due)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.slate600,
                    ),
                  ),
                  if (note.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      note,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color: AppColors.slate600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
