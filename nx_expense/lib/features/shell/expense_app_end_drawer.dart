import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nx_db/auth.dart';

import 'package:nx_expense/core/theme/app_theme.dart';

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

/// Opens [ExpenseAppEndDrawer] on the nearest [Scaffold] with [endDrawer] set.
class ExpenseAppMenuButton extends StatelessWidget {
  const ExpenseAppMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      icon: const Icon(Icons.menu, color: AppColors.slate400, size: 22),
      onPressed: () => Scaffold.of(context).openEndDrawer(),
    );
  }
}
