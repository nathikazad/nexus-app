import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nx_projects/core/layout/is_desktop_layout.dart';
import 'package:nx_projects/features/desktop/desktop_shell.dart';
import 'package:nx_projects/features/shell/mobile_shell.dart';

/// Picks [DesktopShell] vs [MobileShell] from viewport width; [LayoutBuilder] updates on resize.
class NxRootShell extends StatelessWidget {
  const NxRootShell({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        return isDesktopLayoutWidth(c.maxWidth)
            ? const DesktopShell()
            : const MobileShell();
      },
    );
  }
}

/// Simple router: home only (no auth for fake data).
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const NxRootShell(),
      ),
    ],
  );
});
