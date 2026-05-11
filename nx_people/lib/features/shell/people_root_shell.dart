import 'package:flutter/material.dart';
import 'package:nx_people/core/layout/is_desktop_layout.dart';
import 'package:nx_people/features/desktop/desktop_shell.dart';
import 'package:nx_people/features/mobile/mobile_shell.dart';

class PeopleRootShell extends StatelessWidget {
  const PeopleRootShell({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (isDesktopLayoutWidth(constraints.maxWidth)) {
          return const DesktopShell();
        }
        return const MobileShell();
      },
    );
  }
}
