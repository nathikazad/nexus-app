import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nx_projects/core/layout/is_desktop_layout.dart';
import 'package:nx_projects/core/theme/app_theme.dart';
import 'package:nx_projects/data/providers.dart';
import 'package:nx_projects/domain/task/task.dart';
import 'package:nx_projects/domain/task/task_bucket.dart';
import 'package:nx_projects/domain/task/task_status.dart';
import 'package:nx_projects/features/desktop/desktop_task_drawer_state.dart';
import 'package:nx_projects/features/task_edit/task_edit_sheet.dart';

Future<void> showTaskContextSheet(
  BuildContext context,
  WidgetRef ref, {
  required Task task,
  required void Function() onAfterChange,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.panel,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.border2,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            _h('Move to bucket'),
            _act(ctx, ref, 'Bucket NOW', () async {
              await _setBucket(ref, task, TaskBucket.now);
              onAfterChange();
            }),
            _act(ctx, ref, 'NEXT', () async {
              await _setBucket(ref, task, TaskBucket.next);
              onAfterChange();
            }),
            _act(ctx, ref, 'LATER', () async {
              await _setBucket(ref, task, TaskBucket.later);
              onAfterChange();
            }),
            _act(ctx, ref, 'SOMEDAY', () async {
              await _setBucket(ref, task, TaskBucket.someday);
              onAfterChange();
            }),
            const Divider(color: AppColors.border),
            _h('Status'),
            _act(ctx, ref, 'Todo', () async {
              await _setStatus(ref, task, TaskStatus.todo);
              onAfterChange();
            }),
            _act(ctx, ref, 'Doing', () async {
              await _setStatus(ref, task, TaskStatus.doing);
              onAfterChange();
            }),
            _act(ctx, ref, 'Done', () async {
              await _setStatus(ref, task, TaskStatus.done);
              onAfterChange();
            }),
            const Divider(color: AppColors.border),
            ListTile(
              title: const Text('Edit…'),
              onTap: () {
                Navigator.of(ctx).pop();
                if (isDesktopLayout(context)) {
                  ref.read(desktopTaskDrawerProvider.notifier).editTask(task);
                } else {
                  showTaskEditSheet(
                    context,
                    ref,
                    task: task,
                    onSave: onAfterChange,
                  );
                }
              },
            ),
            ListTile(
              title: const Text('Delete', style: TextStyle(color: AppColors.crit)),
              onTap: () async {
                await ref.read(taskRepositoryProvider).delete(task.id);
                ref.invalidate(tasksListAsyncProvider);
                onAfterChange();
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

Widget _h(String t) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        t,
        style: const TextStyle(
          fontSize: 10,
          letterSpacing: 0.6,
          color: AppColors.dim,
        ),
      ),
    ),
  );
}

Widget _act(
  BuildContext context,
  WidgetRef ref,
  String label,
  Future<void> Function() fn,
) {
  return ListTile(
    title: Text(label),
    onTap: () async {
      await fn();
      if (context.mounted) Navigator.of(context).pop();
    },
  );
}

Future<void> _setBucket(WidgetRef ref, Task t, TaskBucket b) async {
  await ref.read(taskRepositoryProvider).upsert(t.copyWith(bucket: b));
  ref.invalidate(tasksListAsyncProvider);
}

Future<void> _setStatus(WidgetRef ref, Task t, TaskStatus s) async {
  await ref.read(taskRepositoryProvider).upsert(t.copyWith(status: s));
  ref.invalidate(tasksListAsyncProvider);
}
