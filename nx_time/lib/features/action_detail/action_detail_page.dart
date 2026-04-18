import 'package:flutter/material.dart';

import 'package:nx_time/core/theme/app_theme.dart';
import 'package:nx_time/features/action_edit/action_edit_page.dart';
import 'package:nx_time/features/action_detail/action_detail_view_model.dart';
import 'package:nx_time/features/action_detail/widgets/category_pill.dart';
import 'package:nx_time/features/action_detail/widgets/linked_task_row.dart';
import 'package:nx_time/features/action_detail/widgets/notes_block.dart';
import 'package:nx_time/features/action_detail/widgets/time_block_bar.dart';

/// Detail for a logged Action (reference: `partials/page-activity-detail-*.html`).
class ActivityDetailPage extends StatelessWidget {
  const ActivityDetailPage({super.key, required this.args});

  final ActivityDetailArgs args;

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
                      minimumSize: const Size(36, 36),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      '←',
                      style: TextStyle(
                        fontSize: 20,
                        color: AppColors.sky600,
                        height: 1,
                      ),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Action detail',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppColors.slate900,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: args.sourceAction == null
                        ? null
                        : () {
                            Navigator.of(context).push<void>(
                              MaterialPageRoute<void>(
                                builder: (_) => ActionEditPage(
                                  mode: ActionEditMode.edit,
                                  initial: args.sourceAction,
                                ),
                              ),
                            );
                          },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Edit',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: args.sourceAction == null
                            ? AppColors.slate300
                            : AppColors.sky600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  Text(
                    args.detailTitle,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      height: 1.2,
                      color: AppColors.slate900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        args.dateLabel,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.slate500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DetailCategoryPill(args: args),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TimeBlockBar(args: args),
                  if (args.description != null && args.description!.trim().isNotEmpty) ...[
                    const SizedBox(height: 14),
                    ActionDetailNotesBlock(text: args.description!.trim()),
                  ],
                  const SizedBox(height: 12),
                  Divider(height: 1, color: AppColors.slate100.withValues(alpha: 0.9)),
                  const SizedBox(height: 12),
                  if (args.tasks.isNotEmpty) ...[
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
                        Text(
                          '${args.linkedTaskCount} tasks',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.slate500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    for (final task in args.tasks) ...[
                      LinkedTaskRow(task: task),
                      const SizedBox(height: 6),
                    ],
                    const Text(
                      'Tap to view task detail',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.slate400,
                      ),
                    ),
                  ] else ...[
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Associated tasks',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.slate900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: Text(
                          'No tasks linked to this action',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.slate400,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Divider(height: 1, color: AppColors.slate100.withValues(alpha: 0.9)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Wearable captures',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.slate900,
                        ),
                      ),
                      TextButton(
                        onPressed: () {},
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          args.wearablePhotoLabel,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.sky600,
                          ),
                        ),
                      ),
                    ],
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
