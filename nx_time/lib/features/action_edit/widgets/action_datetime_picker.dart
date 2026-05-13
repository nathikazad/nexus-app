import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:nx_time/core/theme/app_theme.dart';

/// Date + time (defaults should use [DateTime] with today’s calendar date).
Future<DateTime?> showActionDateTimePicker(
  BuildContext context, {
  required DateTime initialDateTime,
  String title = 'Date & time',
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      var selected = initialDateTime;
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
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
                            onPressed: () =>
                                Navigator.of(context).pop(selected),
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
                      height: 240,
                      child: CupertinoDatePicker(
                        mode: CupertinoDatePickerMode.dateAndTime,
                        use24hFormat: false,
                        initialDateTime: initialDateTime,
                        minimumDate: DateTime(2000),
                        maximumDate: DateTime(2100),
                        onDateTimeChanged: (dt) {
                          setModalState(() {
                            selected = dt;
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
