import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:nx_db/auth.dart';

import 'package:nx_projects/core/theme/app_theme.dart';

/// Reference `reference/desktop/styles.css` `.topbar` + `.top-tab` / `.top-tab.active`.
class DesktopTopBar extends ConsumerWidget {
  const DesktopTopBar({
    super.key,
    required this.activeIndex,
    required this.onSelect,
  });

  /// 0 = Planner, 1 = Sprint, 2 = Today
  final int activeIndex;
  final ValueChanged<int> onSelect;

  static const _labels = <String>['Planner', 'Sprint', 'Today'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: AppColors.panel,
      child: Container(
        height: 44,
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Row(
          children: [
            const Text(
              '◆ Nexus',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
                fontSize: 14,
                color: AppColors.text,
              ),
            ),
            const SizedBox(width: 24),
            for (var i = 0; i < _labels.length; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              _TopTab(
                label: _labels[i],
                selected: activeIndex == i,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onSelect(i);
                },
              ),
            ],
            const Spacer(),
            _AccountButton(
              onLogout: () => ref.read(authProvider.notifier).logout(),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountButton extends StatelessWidget {
  const _AccountButton({required this.onLogout});

  final Future<void> Function() onLogout;

  Future<void> _showLogoutDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.panel,
          title: const Text(
            '@nathik',
            style: TextStyle(color: AppColors.text, fontSize: 16),
          ),
          content: const Text(
            'Logout',
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await onLogout();
              },
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showLogoutDialog(context),
        borderRadius: BorderRadius.circular(6),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Text(
            '@nathik',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ),
      ),
    );
  }
}

class _TopTab extends StatelessWidget {
  const _TopTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? AppColors.panel2 : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Opacity(
            opacity: selected ? 1 : 0.55,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: selected ? AppColors.text : AppColors.muted,
                fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
