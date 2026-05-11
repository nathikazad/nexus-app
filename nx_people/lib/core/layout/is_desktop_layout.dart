import 'package:flutter/widgets.dart';

const double kDesktopBreakpoint = 900;

bool isDesktopLayoutWidth(double width) => width >= kDesktopBreakpoint;

bool isDesktopLayout(BuildContext context) {
  return isDesktopLayoutWidth(MediaQuery.sizeOf(context).width);
}
