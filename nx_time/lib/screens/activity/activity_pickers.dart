import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../app_theme.dart';

/// Category row for pickers (reference edit/add screens).
class ActivityCategoryOption {
  const ActivityCategoryOption(this.label, this.dot);

  final String label;
  final Color dot;

  /// Text color when selected (Work uses dark blue).
  Color get labelColor =>
      label == 'Work' ? const Color(0xFF0C447C) : AppColors.slate900;
}

/// Default list aligned with reference HTML.
const List<ActivityCategoryOption> kActivityCategories = [
  ActivityCategoryOption('Sleep', Color(0xFF534AB7)),
  ActivityCategoryOption('Work', Color(0xFF185FA5)),
  ActivityCategoryOption('Yoga', Color(0xFF1D9E75)),
  ActivityCategoryOption('Eat', Color(0xFFD85A30)),
  ActivityCategoryOption('Shopping', Color(0xFFD4537E)),
  ActivityCategoryOption('Workout', Color(0xFF639922)),
  ActivityCategoryOption('Commute', Color(0xFF888780)),
  ActivityCategoryOption('Reading', Color(0xFFBA7517)),
];

Future<ActivityCategoryOption?> showActivityCategoryPicker(
  BuildContext context, {
  ActivityCategoryOption? selected,
}) {
  return showModalBottomSheet<ActivityCategoryOption>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _CategoryPickerBody(selected: selected),
  );
}

class _CategoryPickerBody extends StatelessWidget {
  const _CategoryPickerBody({this.selected});

  final ActivityCategoryOption? selected;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.slate200,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Select category',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.slate900,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.slate200),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Search categories...',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.slate400,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.42,
                  ),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final c in kActivityCategories)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Material(
                            color: selected?.label == c.label
                                ? const Color(0xFFE6F1FB)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            child: InkWell(
                              onTap: () => Navigator.of(context).pop(c),
                              borderRadius: BorderRadius.circular(10),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: c.dot,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        c.label,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: selected?.label == c.label
                                              ? FontWeight.w500
                                              : FontWeight.w400,
                                          color: selected?.label == c.label
                                              ? c.labelColor
                                              : AppColors.slate900,
                                        ),
                                      ),
                                    ),
                                    if (selected?.label == c.label)
                                      Icon(
                                        Icons.check,
                                        size: 16,
                                        color: c.labelColor,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Time picker in a bottom sheet (Cupertino wheel).
Future<TimeOfDay?> showActivityTimePicker(
  BuildContext context, {
  required TimeOfDay initialTime,
  String title = 'Select time',
}) {
  return showModalBottomSheet<TimeOfDay>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      var selected = initialTime;
      return StatefulBuilder(
        builder: (context, setModalState) {
          final bottom = MediaQuery.viewInsetsOf(context).bottom;
          return Padding(
            padding: EdgeInsets.only(bottom: bottom),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                color: AppColors.sky600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: AppColors.slate900,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(selected),
                            child: const Text(
                              'Done',
                              style: TextStyle(
                                color: AppColors.sky600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 216,
                      child: CupertinoDatePicker(
                        mode: CupertinoDatePickerMode.time,
                        use24hFormat: false,
                        initialDateTime: DateTime(
                          2020,
                          1,
                          1,
                          initialTime.hour,
                          initialTime.minute,
                        ),
                        onDateTimeChanged: (dt) {
                          setModalState(() {
                            selected = TimeOfDay(hour: dt.hour, minute: dt.minute);
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

String formatTimeOfDay(TimeOfDay t) {
  final period = t.period == DayPeriod.am ? 'AM' : 'PM';
  var h = t.hourOfPeriod;
  if (h == 0) h = 12;
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m $period';
}
