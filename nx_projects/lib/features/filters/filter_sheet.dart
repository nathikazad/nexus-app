import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nx_projects/core/theme/app_theme.dart';
import 'package:nx_projects/features/filters/filter_state_providers.dart';

Future<void> showFilterSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.panel,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Consumer(
          builder: (c, r, _) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: AppColors.border2,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  _h('KIND'),
                  _tile(ctx, r, 'kind', 'all', 'All kinds'),
                  _tile(ctx, r, 'kind', 'feat', 'Features only'),
                  _tile(ctx, r, 'kind', 'bug', 'Bugs only'),
                  const Divider(color: AppColors.border),
                  _h('STATUS'),
                  _tile(ctx, r, 'status', 'all', 'All'),
                  _tile(ctx, r, 'status', 'open', 'Open (not done)'),
                  _tile(ctx, r, 'status', 'done', 'Done'),
                  const Divider(color: AppColors.border),
                  ListTile(
                    title: const Text('Reset filters', style: TextStyle(color: AppColors.accent)),
                    onTap: () {
                      r.read(filterKindProvider.notifier).set('all');
                      r.read(filterStatusProvider.notifier).set('all');
                      Navigator.of(ctx).pop();
                    },
                  ),
                ],
              ),
            );
          },
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

Widget _tile(
  BuildContext context,
  WidgetRef ref,
  String field,
  String value,
  String label,
) {
  final cur = field == 'kind' ? ref.watch(filterKindProvider) : ref.watch(filterStatusProvider);
  final selected = cur == value;
  return ListTile(
    title: Text(label),
    trailing: selected ? const Icon(Icons.check, color: AppColors.accent) : null,
    onTap: () {
      if (field == 'kind') {
        ref.read(filterKindProvider.notifier).set(value);
      } else {
        ref.read(filterStatusProvider.notifier).set(value);
      }
      Navigator.of(context).pop();
    },
  );
}
