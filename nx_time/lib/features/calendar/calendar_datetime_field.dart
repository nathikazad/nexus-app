import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CalendarDateTimeField extends StatelessWidget {
  const CalendarDateTimeField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    subtitle: Text(
      value == null
          ? 'Not set'
          : DateFormat('MMM d, yyyy · h:mm a').format(value!),
    ),
    trailing: value == null
        ? const Icon(Icons.calendar_month)
        : IconButton(
            tooltip: 'Clear $label',
            icon: const Icon(Icons.clear),
            onPressed: () => onChanged(null),
          ),
    onTap: () async {
      final initial = value ?? DateTime.now();
      final day = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(1900),
        lastDate: DateTime(2200),
      );
      if (day == null || !context.mounted) return;
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initial),
      );
      if (time != null) {
        onChanged(
          DateTime(day.year, day.month, day.day, time.hour, time.minute),
        );
      }
    },
  );
}
