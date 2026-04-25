import 'package:flutter/material.dart';

/// Min width for `reference/desktop/` shell (top tabs + two-pane). Below: [MobileShell].
const double kDesktopLayoutBreakpoint = 720;

/// Returns true when the viewport is wide enough for the desktop reference shell.
bool isDesktopLayout(BuildContext context) {
  return MediaQuery.sizeOf(context).width >= kDesktopLayoutBreakpoint;
}

bool isDesktopLayoutWidth(double width) => width >= kDesktopLayoutBreakpoint;
