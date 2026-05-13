import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nx_time/core/theme/app_theme.dart';
import 'package:nx_time/data/providers.dart';
import 'package:nx_time/features/action_create/add_child_actions_page.dart';
import 'package:nx_time/features/action_edit/action_edit_page.dart';
import 'package:nx_time/features/action_detail/action_detail_view_model.dart';
import 'package:nx_time/features/action_detail/widgets/category_pill.dart';
import 'package:nx_time/features/action_detail/widgets/linked_task_row.dart';
import 'package:nx_time/features/action_detail/widgets/notes_block.dart';
import 'package:nx_time/features/action_detail/widgets/time_block_bar.dart';
import 'package:nx_time/features/tasks/task_view_models.dart';

/// Detail for a logged Action (reference: `partials/page-activity-detail-*.html`).
///
/// Watches [tasksLinkedToActivityProvider] so any task mutation that invalidates
/// [allTasksProvider] (status change, edit, link, create) flows back here with
/// no manual reload needed.
class ActivityDetailPage extends ConsumerWidget {
  const ActivityDetailPage({super.key, required this.args});

  final ActivityDetailArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final action = args.sourceAction;
    final linkedAsync = action == null
        ? null
        : ref.watch(tasksLinkedToActivityProvider(action.id));
    final colors = modelTypeColorsOrFallback(
      ref.watch(modelTypeColorsProvider),
    );

    final effectiveArgs = linkedAsync == null
        ? args
        : args.copyWith(
            tasks: linkedAsync.maybeWhen(
              data: linkedTaskItemsFromTasks,
              orElse: () => args.tasks,
            ),
          );

    return _ActivityDetailScaffold(
      args: effectiveArgs,
      modelTypeColors: colors,
      onEdit: action == null
          ? null
          : () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => ActionEditPage(
                    mode: ActionEditMode.edit,
                    initial: action,
                  ),
                ),
              );
            },
    );
  }
}

class _ActivityDetailScaffold extends StatelessWidget {
  const _ActivityDetailScaffold({
    required this.args,
    required this.modelTypeColors,
    required this.onEdit,
  });

  final ActivityDetailArgs args;
  final ModelTypeColors modelTypeColors;
  final VoidCallback? onEdit;

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
                    onPressed: onEdit,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
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
                  if (args.layout == ActivityDetailLayout.umbrella) ...[
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Child actions',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.slate900,
                          ),
                        ),
                        Text(
                          '${args.umbrellaChildCount}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.slate500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    for (final c in args.umbrellaChildren) ...[
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            Navigator.of(context).push<void>(
                              MaterialPageRoute<void>(
                                builder: (_) => ActivityDetailPage(
                                  args: activityDetailArgsForAction(
                                    c.sourceAction,
                                    args.dateLabel,
                                    modelTypeColors,
                                  ),
                                ),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 4,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: c.barColor,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        c.title,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.slate900,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${c.timeRangeLabel} · ${c.durationLabel}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.slate500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Text(
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
                    ],
                    if (args.sourceAction != null) ...[
                      const SizedBox(height: 8),
                      DottedBorder(
                        options: const RoundedRectDottedBorderOptions(
                          radius: Radius.circular(10),
                          color: AppColors.slate200,
                          dashPattern: [4, 4],
                          strokeWidth: 1,
                          padding: EdgeInsets.zero,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              Navigator.of(context).push<void>(
                                MaterialPageRoute<void>(
                                  builder: (_) => AddChildActionsPage(
                                    parent: args.sourceAction!,
                                  ),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(
                                    Icons.add_circle_outline,
                                    size: 18,
                                    color: AppColors.slate500,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Add another action',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.slate500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                  if (args.description != null &&
                      args.description!.trim().isNotEmpty) ...[
                    const SizedBox(height: 14),
                    ActionDetailNotesBlock(text: args.description!.trim()),
                  ],
                  const SizedBox(height: 12),
                  Divider(
                    height: 1,
                    color: AppColors.slate100.withValues(alpha: 0.9),
                  ),
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
                      style: TextStyle(fontSize: 11, color: AppColors.slate400),
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
                  Divider(
                    height: 1,
                    color: AppColors.slate100.withValues(alpha: 0.9),
                  ),
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
