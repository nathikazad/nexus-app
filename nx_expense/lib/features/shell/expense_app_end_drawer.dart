import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nx_db/auth.dart';

import 'package:nx_expense/core/theme/app_theme.dart';

enum _ExpenseAppMenuAction { orders, transfers, tags, logout }

/// Panel from the right: Tags (tag systems) and Log out.
class ExpenseAppEndDrawer extends ConsumerWidget {
  const ExpenseAppEndDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Text(
                'Menu',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.slate900,
                ),
              ),
            ),
            const Divider(height: 1, color: AppColors.slate100),
            ListTile(
              leading: const Icon(
                Icons.inventory_2_outlined,
                color: AppColors.slate600,
                size: 22,
              ),
              title: Text(
                'Orders',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () {
                Navigator.of(context).pop();
                context.push('/orders');
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.swap_horiz_outlined,
                color: AppColors.slate600,
                size: 22,
              ),
              title: Text(
                'Transfers',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () {
                Navigator.of(context).pop();
                context.push('/transfers');
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.label_outlined,
                color: AppColors.slate600,
                size: 22,
              ),
              title: Text(
                'Tags',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () {
                Navigator.of(context).pop();
                context.push('/tag-systems');
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.logout,
                color: AppColors.slate600,
                size: 22,
              ),
              title: Text(
                'Log out',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () async {
                Navigator.of(context).pop();
                await ref.read(authProvider.notifier).logout();
                if (context.mounted) context.go('/login');
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Popup menu for secondary app sections and account actions.
class ExpenseAppMenuButton extends ConsumerWidget {
  const ExpenseAppMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<_ExpenseAppMenuAction>(
      tooltip: 'Menu',
      icon: const Icon(Icons.menu, color: AppColors.slate400, size: 22),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      offset: const Offset(0, 38),
      color: Colors.white,
      onSelected: (action) async {
        switch (action) {
          case _ExpenseAppMenuAction.orders:
            context.push('/orders');
          case _ExpenseAppMenuAction.transfers:
            context.push('/transfers');
          case _ExpenseAppMenuAction.tags:
            context.push('/tag-systems');
          case _ExpenseAppMenuAction.logout:
            await ref.read(authProvider.notifier).logout();
            if (context.mounted) context.go('/login');
        }
      },
      itemBuilder: (context) => [
        _item(
          value: _ExpenseAppMenuAction.orders,
          icon: Icons.inventory_2_outlined,
          label: 'Orders',
        ),
        _item(
          value: _ExpenseAppMenuAction.transfers,
          icon: Icons.swap_horiz_outlined,
          label: 'Transfers',
        ),
        _item(
          value: _ExpenseAppMenuAction.tags,
          icon: Icons.label_outlined,
          label: 'Tags',
        ),
        _item(
          value: _ExpenseAppMenuAction.logout,
          icon: Icons.logout,
          label: 'Log out',
        ),
      ],
    );
  }

  PopupMenuItem<_ExpenseAppMenuAction> _item({
    required _ExpenseAppMenuAction value,
    required IconData icon,
    required String label,
  }) {
    return PopupMenuItem<_ExpenseAppMenuAction>(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: AppColors.slate600, size: 20),
          const SizedBox(width: 12),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.slate900,
            ),
          ),
        ],
      ),
    );
  }
}
