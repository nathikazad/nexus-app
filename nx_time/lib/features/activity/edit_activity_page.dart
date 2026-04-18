import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../tasks/task_picker_page.dart';
import 'activity_pickers.dart';

/// Reference: `partials/page-edit-activity.html` — category & time open bottom sheets on tap.
class EditActivityPage extends StatefulWidget {
  const EditActivityPage({super.key});

  @override
  State<EditActivityPage> createState() => _EditActivityPageState();
}

class _EditActivityPageState extends State<EditActivityPage> {
  late ActivityCategoryOption _category;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;

  @override
  void initState() {
    super.initState();
    _category = kActivityCategories.firstWhere((c) => c.label == 'Work');
    _startTime = const TimeOfDay(hour: 8, minute: 30);
    _endTime = const TimeOfDay(hour: 11, minute: 15);
  }

  Future<void> _pickCategory() async {
    final choice = await showActivityCategoryPicker(
      context,
      selected: _category,
    );
    if (choice != null && mounted) {
      setState(() => _category = choice);
    }
  }

  Future<void> _pickStart() async {
    final t = await showActivityTimePicker(
      context,
      initialTime: _startTime,
      title: 'Start time',
    );
    if (t != null && mounted) {
      setState(() => _startTime = t);
    }
  }

  Future<void> _pickEnd() async {
    final t = await showActivityTimePicker(
      context,
      initialTime: _endTime,
      title: 'End time',
    );
    if (t != null && mounted) {
      setState(() => _endTime = t);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.sky600,
                      ),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Edit activity',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppColors.slate900,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                    child: const Text(
                      'Save',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.sky600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  const Text(
                    'Name',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.slate900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _borderBox(
                    child: const Text(
                      'Deep work — auth refactor',
                      style: TextStyle(fontSize: 14, color: AppColors.slate900),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Category',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.slate900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _pickCategory,
                      borderRadius: BorderRadius.circular(10),
                      child: _borderBox(
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: _category.dot,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _category.label,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.slate900,
                                ),
                              ),
                            ),
                            Text(
                              'Change ▶',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.slate400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Start time',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.slate900,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _pickStart,
                                borderRadius: BorderRadius.circular(10),
                                child: _borderBox(
                                  child: Center(
                                    child: Text(
                                      formatTimeOfDay(_startTime),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: AppColors.slate900,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'End time',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.slate900,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _pickEnd,
                                borderRadius: BorderRadius.circular(10),
                                child: _borderBox(
                                  child: Center(
                                    child: Text(
                                      formatTimeOfDay(_endTime),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: AppColors.slate900,
                                      ),
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
                  const SizedBox(height: 12),
                  Divider(height: 1, color: AppColors.slate100.withValues(alpha: 0.9)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Associated tasks',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.slate900,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push<void>(
                            MaterialPageRoute(builder: (_) => const TaskPickerPage()),
                          );
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          '+ Add task',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.sky600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _taskEditRow(
                    title: 'Refactor token validation',
                    subtitle: 'Platform › Auth',
                  ),
                  const SizedBox(height: 6),
                  _taskEditRow(
                    title: 'Review PR for auth flow',
                    subtitle: 'Platform › Auth',
                  ),
                  const SizedBox(height: 12),
                  Divider(height: 1, color: AppColors.slate100.withValues(alpha: 0.9)),
                  const SizedBox(height: 12),
                  const Text(
                    'Notes',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.slate900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _borderBox(
                    minHeight: 64,
                    alignment: Alignment.topLeft,
                    child: const Text(
                      'Finished the main token refresh logic. Still need to wire up the revocation endpoint.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.slate500,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Divider(height: 1, color: AppColors.slate100.withValues(alpha: 0.9)),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFFECACA)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Delete activity',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFFDC2626),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _borderBox({
    required Widget child,
    double minHeight = 0,
    AlignmentGeometry alignment = Alignment.centerLeft,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      constraints: BoxConstraints(minHeight: minHeight > 0 ? minHeight : 42),
      alignment: alignment,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.slate200),
        borderRadius: BorderRadius.circular(10),
      ),
      child: child,
    );
  }

  static Widget _taskEditRow({required String title, required String subtitle}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.slate50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.slate900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.slate400,
                  ),
                ),
              ],
            ),
          ),
          const Text(
            'Remove',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFFDC2626),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
