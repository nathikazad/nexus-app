import 'package:nx_expense/features/desktop/desktop_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nx_db/auth.dart';

import 'package:nx_expense/core/theme/app_theme.dart';

enum _ExpenseAppMenuAction { orders, tags, images, logout }

/// Secondary sections and account actions.
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
                navPush(context, '/orders');
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
                navPush(context, '/tag-systems');
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library_outlined,
                color: AppColors.slate600,
                size: 22,
              ),
              title: Text(
                'Images',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () {
                Navigator.of(context).pop();
                navPush(context, '/images');
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
            navPush(context, '/orders');
          case _ExpenseAppMenuAction.tags:
            navPush(context, '/tag-systems');
          case _ExpenseAppMenuAction.images:
            navPush(context, '/images');
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
          value: _ExpenseAppMenuAction.tags,
          icon: Icons.label_outlined,
          label: 'Tags',
        ),
        _item(
          value: _ExpenseAppMenuAction.images,
          icon: Icons.photo_library_outlined,
          label: 'Images',
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
