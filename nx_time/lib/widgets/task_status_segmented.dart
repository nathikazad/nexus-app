import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../features/tasks/task_status.dart';

/// iOS-style segmented control for task status (reference HTML `setTaskStatus`).
class TaskStatusSegmented extends StatelessWidget {
  const TaskStatusSegmented({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final TaskStatus value;
  final ValueChanged<TaskStatus> onChanged;

  static const _inactive = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.slate500,
  );

  static const _active = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.accent,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.slate100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: TaskStatus.values.map((s) {
          final selected = s == value;
          return Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onChanged(s),
                borderRadius: BorderRadius.circular(8),
                child: Semantics(
                  button: true,
                  selected: selected,
                  label: s.label,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    decoration: BoxDecoration(
                      color: selected ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 0,
                                offset: const Offset(0, 1),
                              ),
                            ]
                          : null,
                      border: selected
                          ? Border.all(color: Colors.black.withValues(alpha: 0.04))
                          : null,
                    ),
                    child: Text(
                      s.label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: selected ? _active : _inactive,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
