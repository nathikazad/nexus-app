import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_people/features/auth/people_login_screen.dart';
import 'package:nx_people/features/shell/people_root_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authProvider, (_, __) => refresh.value++);

  return GoRouter(
    refreshListenable: refresh,
    initialLocation: '/people',
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      if (auth.isLoading) return null;
      final loggedIn = auth.value != null;
      final path = state.uri.path;
      if (!loggedIn && path != '/login') return '/login';
      if (loggedIn && path == '/login') return '/people';
      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: '/login',
        builder: (context, state) => const PeopleLoginScreen(),
      ),
      GoRoute(path: '/', redirect: (context, state) => '/people'),
      GoRoute(
        path: '/people',
        builder: (context, state) => const PeopleRootShell(),
      ),
    ],
  );
});
