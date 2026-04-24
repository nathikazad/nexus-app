import 'package:flutter/material.dart';

/// `#RRGGBB` in uppercase, no alpha (matches [colorFromHex]).
String hexFromColor(Color c) {
  final rgb = c.toARGB32() & 0xFFFFFF;
  return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

/// Parses `#RRGGBB` or `RRGGBB` (case-insensitive); falls back to opaque black on failure.
Color colorFromHex(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return const Color(0xFF000000);
  if (s.startsWith('#')) s = s.substring(1);
  if (s.length == 6) {
    final v = int.tryParse(s, radix: 16);
    if (v != null) return Color(0xFF000000 | v);
  }
  return const Color(0xFF000000);
}

/// Stable distinct color per concrete model type id — used for Today list rows,
/// time bar segments, legend swatches, and action detail category pill (same as list).
Color barColorForModelTypeId(int modelTypeId) {
  const golden = 0x9E3779B9;
  final hue = (modelTypeId * golden) % 360;
  return HSLColor.fromAHSL(1.0, hue.toDouble(), 0.52, 0.48).toColor();
}

/// Pill styling derived from [barColorForModelTypeId] so detail matches list/bar hue.
({Color background, Color foreground, Color dot}) categoryPillStyleFromBarColor(
  Color bar,
) {
  final hsl = HSLColor.fromColor(bar);
  final background = hsl
      .withSaturation((hsl.saturation * 0.22).clamp(0.05, 0.45))
      .withLightness(0.94)
      .toColor();
  final foreground = hsl
      .withSaturation((hsl.saturation * 0.9).clamp(0.35, 1.0))
      .withLightness(0.24)
      .toColor();
  return (background: background, foreground: foreground, dot: bar);
}
