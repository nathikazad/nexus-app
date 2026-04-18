import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nx_db/nx_db.dart';

import 'features/auth/time_login_screen.dart';
import 'features/shell/app_shell.dart';

/// Root router: `/login` when unauthenticated, `/today` for [AppShell].
///
/// [initialTabIndex] is only applied on first load (e.g. screenshot tests via `?tab=`).
final routerProvider = Provider.family<GoRouter, int>((ref, initialTabIndex) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authProvider, (_, __) => refresh.value++);

  final initial = initialTabIndex == 0
      ? '/today'
      : '/today?tab=$initialTabIndex';

  return GoRouter(
    refreshListenable: refresh,
    initialLocation: initial,
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
        return '/today';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const TimeLoginScreen(),
      ),
      GoRoute(
        path: '/today',
        builder: (context, state) {
          final tab =
              int.tryParse(state.uri.queryParameters['tab'] ?? '0') ?? 0;
          return AppShell(initialTabIndex: tab);
        },
      ),
    ],
  );
});
