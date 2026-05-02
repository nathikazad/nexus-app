import 'package:flutter/material.dart';

/// Common spacing and layout (see `reference/mobile/styles.css` `.app`, `.content`).
abstract final class NxLayout {
  /// `reference` `.app { max-width: 520px }` phone column
  static const double maxAppWidth = 520;

  static const double screenHPadding = 12;
  static const double topBarMinH = 56;
  static const double rowRadius = 10;
  static const double drillRadius = 12;
  static const double fabSize = 52;
  static const EdgeInsets topBarHPadding = EdgeInsets.fromLTRB(14, 0, 14, 10);

  /// `.content` padding
  static const EdgeInsets contentPadding = EdgeInsets.fromLTRB(12, 4, 12, 16);
  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(10));
}
