import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_theme.dart';

/// Spacing and radii from [mobile/plans/current/reference-design.html] (Tailwind).
abstract final class RefLayout {
  static const double px5 = 20;
  static const double pt12 = 48;
  static const double pb4 = 16;
  static const double pb3 = 12;
  static const double pb24 = 96;
  static const double gap2 = 8;
  static const double gap15 = 6;
  static const double rounded2xl = 16;
  static const double rounded3xl = 24;
  static const double navHeight = 80;
  static const double fabSize = 56;
  static const double fabBottom = 96;
}

/// Card shadow: shadow-[0_2px_10px_-4px_rgba(0,0,0,0.05)]
List<BoxShadow> get refCardShadow => [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.05),
        blurRadius: 10,
        offset: const Offset(0, 2),
        spreadRadius: -4,
      ),
    ];

/// FAB shadow: shadow-[0_8px_20px_-6px_rgba(13,148,136,0.6)]
List<BoxShadow> get refFabShadow => [
      BoxShadow(
        color: const Color(0x990D9488),
        blurRadius: 20,
        offset: const Offset(0, 8),
        spreadRadius: -6,
      ),
    ];

TextStyle refSectionTitle(BuildContext context) => GoogleFonts.inter(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.2,
      color: AppColors.slate400,
    );

TextStyle refAppBarTitleLarge() => GoogleFonts.inter(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.3,
      color: AppColors.slate900,
    );

TextStyle refAppBarTitleBase() => GoogleFonts.inter(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.3,
      color: AppColors.slate900,
    );
