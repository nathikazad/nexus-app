import 'package:flutter/material.dart';
import 'package:nx_notes/core/theme/app_theme.dart';
import 'package:nx_notes/domain/essay/essay.dart';

class EssayRow extends StatelessWidget {
  const EssayRow({required this.essay, required this.onTap, super.key});

  final Essay essay;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.panel,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  StatusDot(status: essay.status),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      essay.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                '${essay.status} · ${essay.topics.isEmpty ? 'Untagged' : essay.topics.first} · ${essay.updatedLabel}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: 4),
              Text(
                essay.excerpt,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StatusDot extends StatelessWidget {
  const StatusDot({required this.status, super.key});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        color: switch (status) {
          'Draft' => AppColors.amber,
          'In Progress' => AppColors.blue,
          'Published' => AppColors.green,
          'Discarded' => AppColors.red,
          _ => AppColors.muted,
        },
        shape: BoxShape.circle,
      ),
    );
  }
}
