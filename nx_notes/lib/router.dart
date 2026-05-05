import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_notes/features/auth/notes_login_screen.dart';
import 'package:nx_notes/features/shell/notes_root_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authProvider, (_, __) => refresh.value++);

  return GoRouter(
    refreshListenable: refresh,
    initialLocation: '/notes',
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      if (auth.isLoading) return null;
      final loggedIn = auth.value != null;
      final path = state.uri.path;
      if (!loggedIn && path != '/login') return '/login';
      if (loggedIn && path == '/login') return '/notes';
      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: '/login',
        builder: (context, state) => const NotesLoginScreen(),
      ),
      GoRoute(path: '/', redirect: (context, state) => '/notes'),
      GoRoute(
        path: '/notes',
        builder: (context, state) => const NotesRootShell(),
      ),
    ],
  );
});
