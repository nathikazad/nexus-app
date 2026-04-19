import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:nexus_voice_assistant/core/theme/app_theme.dart';

/// Spacing and radii aligned with reference HTML (Tailwind-style).
abstract final class RefLayout {
  static const double px5 = 20;
  static const double p4 = 16;
  static const double gap4 = 16;
  static const double rounded2xl = 16;
  static const double sheetHandleWidth = 40;
  static const double sheetHandleHeight = 4;
}

/// Card shadow: shadow-sm
List<BoxShadow> get refCardShadow => [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.05),
        blurRadius: 10,
        offset: const Offset(0, 2),
        spreadRadius: -4,
      ),
    ];

TextStyle refAppBarTitleLarge() => GoogleFonts.inter(
      fontSize: 20,
      fontWeight: FontWeight.w500,
      letterSpacing: -0.3,
      color: AppColors.gray900,
    );
