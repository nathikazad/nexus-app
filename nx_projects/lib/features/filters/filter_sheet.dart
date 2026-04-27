import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nx_projects/core/theme/app_theme.dart';
import 'package:nx_projects/features/filters/filter_state_providers.dart';

bool _isMobileStatusOpenSet(Set<String> s) {
  return s.length == 3 &&
      s.contains('todo') &&
      s.contains('doing') &&
      s.contains('blocked');
}

bool _isMobileStatusDoneSet(Set<String> s) {
  return s.length == 1 && s.contains('done');
}

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
                  _tileKind(ctx, r, 'all', 'All kinds'),
                  _tileKind(ctx, r, 'feat', 'Features only'),
                  _tileKind(ctx, r, 'bug', 'Bugs only'),
                  const Divider(color: AppColors.border),
                  _h('STATUS'),
                  _tileStatus(ctx, r, 'all', 'All'),
                  _tileStatus(ctx, r, 'open', 'Open (not done)'),
                  _tileStatus(ctx, r, 'done', 'Done'),
                  const Divider(color: AppColors.border),
                  ListTile(
                    title: const Text(
                      'Reset filters',
                      style: TextStyle(color: AppColors.accent),
                    ),
                    onTap: () {
                      r.read(filterKindSetProvider.notifier).clear();
                      r.read(filterStatusSetProvider.notifier).clear();
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

Widget _tileKind(
  BuildContext context,
  WidgetRef ref,
  String value,
  String label,
) {
  final cur = ref.watch(filterKindSetProvider);
  final selected = switch (value) {
    'all' => cur.isEmpty,
    'feat' => cur.length == 1 && cur.contains('feat'),
    'bug' => cur.length == 1 && cur.contains('bug'),
    _ => false,
  };
  return ListTile(
    title: Text(label),
    trailing: selected ? const Icon(Icons.check, color: AppColors.accent) : null,
    onTap: () {
      ref.read(filterKindSetProvider.notifier).setMobileKind(value);
      Navigator.of(context).pop();
    },
  );
}

Widget _tileStatus(
  BuildContext context,
  WidgetRef ref,
  String value,
  String label,
) {
  final cur = ref.watch(filterStatusSetProvider);
  final selected = switch (value) {
    'all' => cur.isEmpty,
    'open' => _isMobileStatusOpenSet(cur),
    'done' => _isMobileStatusDoneSet(cur),
    _ => false,
  };
  return ListTile(
    title: Text(label),
    trailing: selected ? const Icon(Icons.check, color: AppColors.accent) : null,
    onTap: () {
      ref.read(filterStatusSetProvider.notifier).setMobileStatus(value);
      Navigator.of(context).pop();
    },
  );
}
