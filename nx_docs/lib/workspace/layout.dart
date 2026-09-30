import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

const double kDesktopBreakpoint = 900;
// Below this width, a docked navigator and inspector leave too little reading room.
const double kDockedInspectorBreakpoint = 1280;

bool isDesktopLayoutWidth(double width) => width >= kDesktopBreakpoint;

bool isDesktopLayout(BuildContext context) {
  return isDesktopLayoutWidth(MediaQuery.sizeOf(context).width);
}

// Touch input remains touch input when a tablet rotates into a wide layout.
bool usesTouchEditingControls(BuildContext context) =>
    defaultTargetPlatform == TargetPlatform.iOS ||
    defaultTargetPlatform == TargetPlatform.android ||
    !isDesktopLayout(context);
