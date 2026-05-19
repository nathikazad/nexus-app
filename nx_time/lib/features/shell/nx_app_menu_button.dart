import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_views/nx_views.dart';

import 'package:nx_time/core/theme/app_theme.dart';
import 'package:nx_time/features/images/images_page.dart';
import 'package:nx_time/features/log_tags/log_tags_page.dart';
import 'package:nx_time/features/settings/action_colors_page.dart';

/// Hamburger menu; opens app-level tools.
class NxAppMenuButton extends ConsumerWidget {
  const NxAppMenuButton({super.key});

  static void _onColors(BuildContext context) {
    Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => const ActionColorsPage()));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      tooltip: 'Menu',
      offset: const Offset(0, 40),
      icon: const Icon(Icons.menu, color: AppColors.slate400, size: 22),
      onSelected: (value) async {
        if (value == 'colors') {
          _onColors(context);
        } else if (value == 'tags') {
          Navigator.of(context).push<void>(
            MaterialPageRoute<void>(builder: (_) => const LogTagsPage()),
          );
        } else if (value == 'desktop') {
          Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => const ImagesPage(
                initialSource: 'desktop',
                allowSourceSwitch: false,
              ),
            ),
          );
        } else if (value == 'necklace') {
          Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => const ImagesPage(
                initialSource: 'necklace',
                allowSourceSwitch: false,
              ),
            ),
          );
        } else if (value == 'gps') {
          Navigator.of(context).push<void>(
            MaterialPageRoute<void>(builder: (_) => const GpsPage()),
          );
        } else if (value == 'logout') {
          await ref.read(authProvider.notifier).logout();
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Logged out')));
          }
        }
      },
      itemBuilder: (context) => [
        _menuItem('tags', Icons.label_outline, 'Tags'),
        _menuItem('colors', Icons.palette_outlined, 'Colors'),
        _menuItem('desktop', Icons.desktop_windows_outlined, 'Desktop'),
        _menuItem('necklace', Icons.camera_alt_outlined, 'Necklace'),
        _menuItem('gps', Icons.location_on_outlined, 'GPS'),
        _menuItem('logout', Icons.logout, 'Logout'),
      ],
    );
  }

  PopupMenuItem<String> _menuItem(String value, IconData icon, String label) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.slate500),
          const SizedBox(width: 12),
          Text(
            label,
            style: GoogleFonts.inter(
              color: AppColors.slate900,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
