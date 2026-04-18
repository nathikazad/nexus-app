import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../tasks/task_picker_page.dart';
import 'activity_pickers.dart';

/// Reference: `partials/page-add-time-block.html` — category & times open pickers on tap.
class AddTimeBlockPage extends StatefulWidget {
  const AddTimeBlockPage({super.key});

  @override
  State<AddTimeBlockPage> createState() => _AddTimeBlockPageState();
}

class _AddTimeBlockPageState extends State<AddTimeBlockPage> {
  ActivityCategoryOption? _category;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

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
      initialTime: _startTime ?? const TimeOfDay(hour: 9, minute: 0),
      title: 'Start time',
    );
    if (t != null && mounted) {
      setState(() => _startTime = t);
    }
  }

  Future<void> _pickEnd() async {
    final t = await showActivityTimePicker(
      context,
      initialTime: _endTime ?? const TimeOfDay(hour: 10, minute: 0),
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
                      'Add time block',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppColors.slate900,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {},
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                    child: Text(
                      'Save',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.slate400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
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
                  _OutlineField(
                    child: Text(
                      'e.g., Evening walk, Reading...',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.slate400,
                      ),
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
                      child: _OutlineField(
                        child: _category == null
                            ? Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Select category',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: AppColors.slate400,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '▶',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.slate400,
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: _category!.dot,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _category!.label,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: AppColors.slate900,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '▶',
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
                                child: _OutlineField(
                                  child: Center(
                                    child: Text(
                                      _startTime == null
                                          ? 'Tap to set'
                                          : formatTimeOfDay(_startTime!),
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: _startTime == null
                                            ? AppColors.slate400
                                            : AppColors.slate900,
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
                                child: _OutlineField(
                                  child: Center(
                                    child: Text(
                                      _endTime == null
                                          ? 'Tap to set'
                                          : formatTimeOfDay(_endTime!),
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: _endTime == null
                                            ? AppColors.slate400
                                            : AppColors.slate900,
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
                  const Center(
                    child: Text(
                      'No tasks linked yet',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.slate400,
                      ),
                    ),
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
                  _OutlineField(
                    alignment: Alignment.topLeft,
                    minHeight: 64,
                    child: Text(
                      'Optional — add notes...',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.slate400,
                        height: 1.5,
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
}

class _OutlineField extends StatelessWidget {
  const _OutlineField({
    required this.child,
    this.alignment = Alignment.centerLeft,
    this.minHeight = 0,
  });

  final Widget child;
  final AlignmentGeometry alignment;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
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
}
