import 'package:flutter/material.dart';

import 'package:nx_time/core/theme/app_theme.dart';
import 'package:nx_time/features/action_detail/action_detail_view_model.dart';
import 'package:nx_time/features/tasks/task_detail_page.dart';

class LinkedTaskRow extends StatelessWidget {
  const LinkedTaskRow({super.key, required this.task});

  final LinkedTaskItem task;

  @override
  Widget build(BuildContext context) {
    final id = task.taskId;
    return Material(
      color: AppColors.slate50,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: id == null
            ? null
            : () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => TaskDetailPage(taskId: id),
                  ),
                );
              },
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              _TaskGlyph(progress: task.progress),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.slate900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      task.subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.slate400,
                      ),
                    ),
                  ],
                ),
              ),
              const Text(
                '▶',
                style: TextStyle(fontSize: 12, color: AppColors.slate400),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskGlyph extends StatelessWidget {
  const _TaskGlyph({required this.progress});

  final LinkedTaskProgress progress;

  @override
  Widget build(BuildContext context) {
    switch (progress) {
      case LinkedTaskProgress.partialBlue:
        return SizedBox(
          width: 18,
          height: 18,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.calBlue, width: 1.5),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 10,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.calBlue.withValues(alpha: 0.28),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(2),
                      bottomRight: Radius.circular(2),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      case LinkedTaskProgress.doneGreen:
        return Container(
          width: 18,
          height: 18,
          decoration: const BoxDecoration(
            color: Color(0xFF1D9E75),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check,
            size: 11,
            color: Colors.white,
          ),
        );
    }
  }
}
