import 'package:flutter/material.dart';
import 'package:nx_notes/core/layout/is_desktop_layout.dart';
import 'package:nx_notes/features/desktop/desktop_shell.dart';
import 'package:nx_notes/features/mobile/mobile_shell.dart';

class NotesRootShell extends StatelessWidget {
  const NotesRootShell({super.key});

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
