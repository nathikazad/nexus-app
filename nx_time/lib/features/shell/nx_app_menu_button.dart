import 'package:nx_time/features/schedule/schedule_page.dart';
import 'package:nx_time/features/settings/settings_page.dart';
import 'package:nx_time/features/calendar/history_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nx_views/nx_views.dart';

import 'package:nx_time/core/theme/app_theme.dart';
import 'package:nx_time/features/images/images_page.dart';
import 'package:nx_time/features/log_tags/log_tags_page.dart';

/// Hamburger menu; opens app-level tools.
class NxAppMenuButton extends ConsumerWidget {
  const NxAppMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      tooltip: 'Menu',
      offset: const Offset(0, 40),
      icon: const Icon(Icons.menu, color: AppColors.slate400, size: 22),
      onSelected: (value) async {
        if (value == 'settings') {
          Navigator.of(
            context,
          ).push<void>(MaterialPageRoute(builder: (_) => const SettingsPage()));
        } else if (value == 'schedule') {
          Navigator.of(
            context,
          ).push<void>(MaterialPageRoute(builder: (_) => const SchedulePage()));
        } else if (value == 'history') {
          Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) => const Scaffold(body: HistoryPage()),
            ),
          );
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
        }
      },
      itemBuilder: (context) => [
        _menuItem('settings', Icons.settings_outlined, 'Settings'),
        _menuItem('schedule', Icons.schedule, 'Schedule'),
        _menuItem('history', Icons.history, 'History'),
        _menuItem('tags', Icons.label_outline, 'Daily log tags'),
        _menuItem('desktop', Icons.desktop_windows_outlined, 'Desktop'),
        _menuItem('necklace', Icons.camera_alt_outlined, 'Necklace'),
        _menuItem('gps', Icons.location_on_outlined, 'GPS'),
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
