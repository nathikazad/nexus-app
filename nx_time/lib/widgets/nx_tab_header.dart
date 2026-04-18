import 'package:flutter/material.dart';
import 'package:solar_icon_pack/solar_icon_pack.dart';

import '../theme/app_colors.dart';

/// Clock + centered title + optional trailing (Tasks / Goals / Calendar pattern).
class NxTabHeader extends StatelessWidget {
  const NxTabHeader({
    super.key,
    required this.clockLabel,
    required this.title,
    this.trailing,
    this.bottomBorder = false,
    this.borderColor = AppColors.slate50,
  });

  final String clockLabel;
  final String title;
  final Widget? trailing;
  final bool bottomBorder;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        decoration: bottomBorder
            ? BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: borderColor),
                ),
              )
            : null,
        padding: const EdgeInsets.fromLTRB(20, 12, 12, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              clockLabel,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.slate500,
              ),
            ),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                  color: AppColors.slate900,
                ),
              ),
            ),
            trailing ??
                IconButton(
                  onPressed: () {},
                  icon: const Icon(SolarLinearIcons.settings, size: 24),
                  color: AppColors.slate500,
                ),
          ],
        ),
      ),
    );
  }
}
