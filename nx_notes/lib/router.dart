import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_notes/features/auth/notes_login_screen.dart';
import 'package:nx_notes/features/shell/notes_root_shell.dart';

class NotesInitializingScreen extends StatelessWidget {
  const NotesInitializingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authProvider, (_, __) => refresh.value++);

  return GoRouter(
    refreshListenable: refresh,
    initialLocation: '/notes',
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final path = state.uri.path;
      if (auth.isLoading) {
        return path == '/initializing' ? null : '/initializing';
      }
      final loggedIn = auth.value != null;
      if (path == '/initializing') return loggedIn ? '/notes' : '/login';
      if (!loggedIn && path != '/login') return '/login';
      if (loggedIn && path == '/login') return '/notes';
      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: '/login',
        builder: (context, state) => const NotesLoginScreen(),
      ),
      GoRoute(
        path: '/initializing',
        builder: (context, state) => const NotesInitializingScreen(),
      ),
      GoRoute(path: '/', redirect: (context, state) => '/notes'),
      GoRoute(
        path: '/notes',
        builder: (context, state) => const NotesRootShell(),
      ),
    ],
  );
});
