import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Tabs not built yet — keeps shell navigation consistent.
class PlaceholderTab extends StatelessWidget {
  const PlaceholderTab({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '$title — coming soon',
        style: const TextStyle(
          fontSize: 15,
          color: AppColors.slate500,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
