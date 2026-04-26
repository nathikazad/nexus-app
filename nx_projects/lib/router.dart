import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nx_db/auth.dart';

import 'package:nx_projects/core/layout/is_desktop_layout.dart';
import 'package:nx_projects/features/auth/projects_login_screen.dart';
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

/// Root router: `/login` when unauthenticated, `/` for [NxRootShell].
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authProvider, (_, __) => refresh.value++);

  return GoRouter(
    refreshListenable: refresh,
    initialLocation: '/',
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      if (auth.isLoading) {
        return null;
      }
      final user = auth.value;
      final path = state.uri.path;
      if (user == null && path != '/login') {
        return '/login';
      }
      if (user != null && path == '/login') {
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const ProjectsLoginScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const NxRootShell(),
      ),
    ],
  );
});
