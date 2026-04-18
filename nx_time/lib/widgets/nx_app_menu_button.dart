import 'package:flutter/material.dart';

import '../screens/settings/action_colors_page.dart';
import '../app_theme.dart';

/// Hamburger menu (aligned with `nx_expense` [ExpenseAppMenuButton]); opens Colors + Logout.
class NxAppMenuButton extends StatelessWidget {
  const NxAppMenuButton({super.key});

  static void _onColors(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const ActionColorsPage()),
    );
  }

  static void _onLogout(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Logged out')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      tooltip: 'Menu',
      offset: const Offset(0, 40),
      icon: const Icon(Icons.menu, color: AppColors.slate400, size: 22),
      onSelected: (value) {
        if (value == 'colors') {
          _onColors(context);
        } else if (value == 'logout') {
          _onLogout(context);
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem<String>(
          value: 'colors',
          child: Text('Colors'),
        ),
        PopupMenuItem<String>(
          value: 'logout',
          child: Text('Logout'),
        ),
      ],
    );
  }
}
