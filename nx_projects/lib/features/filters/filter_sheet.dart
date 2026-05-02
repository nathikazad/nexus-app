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
    backgroundColor: context.colors.panel,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Consumer(
          builder: (c, r, _) {
            return Padding(
              padding: EdgeInsets.fromLTRB(8, 8, 8, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: context.colors.border2,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  _h(ctx, 'KIND'),
                  _tileKind(ctx, r, 'all', 'All kinds'),
                  _tileKind(ctx, r, 'feat', 'Features only'),
                  _tileKind(ctx, r, 'bug', 'Bugs only'),
                  Divider(color: context.colors.border),
                  _h(ctx, 'STATUS'),
                  _tileStatus(ctx, r, 'all', 'All'),
                  _tileStatus(ctx, r, 'open', 'Open (not done)'),
                  _tileStatus(ctx, r, 'done', 'Done'),
                  Divider(color: context.colors.border),
                  ListTile(
                    title: Text(
                      'Reset filters',
                      style: TextStyle(color: context.colors.accent),
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

Widget _h(BuildContext context, String t) {
  return Padding(
    padding: EdgeInsets.fromLTRB(14, 10, 14, 4),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        t,
        style: TextStyle(
          fontSize: 10,
          letterSpacing: 0.6,
          color: context.colors.dim,
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
    trailing: selected ? Icon(Icons.check, color: context.colors.accent) : null,
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
    trailing: selected ? Icon(Icons.check, color: context.colors.accent) : null,
    onTap: () {
      ref.read(filterStatusSetProvider.notifier).setMobileStatus(value);
      Navigator.of(context).pop();
    },
  );
}
