import 'package:flutter/material.dart';

import 'package:nx_time/core/theme/app_theme.dart';
import 'package:nx_time/features/shell/nx_app_menu_button.dart';

/// Centered title with an optional trailing widget (defaults to the app menu button).
///
/// Uses a [Stack] so the title is centered against the full row width, not
/// the space remaining after the trailing icon — keeping the text visually
/// centered regardless of the menu button.
class NxTabHeader extends StatelessWidget {
  const NxTabHeader({
    super.key,
    required this.title,
    this.trailing,
    this.bottomBorder = false,
    this.borderColor = AppColors.slate50,
  });

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
                border: Border(bottom: BorderSide(color: borderColor)),
              )
            : null,
        padding: const EdgeInsets.fromLTRB(12, 2, 12, 2),
        child: SizedBox(
          height: 40,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Center(
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
              Align(
                alignment: Alignment.centerRight,
                child: trailing ?? const NxAppMenuButton(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
