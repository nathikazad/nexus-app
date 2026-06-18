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
    initialLocation: '/docs',
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final path = state.uri.path;
      if (auth.isLoading) {
        if (path == '/initializing') return null;
        return '/initializing?from=${Uri.encodeComponent(_routeDestination(state))}';
      }
      final loggedIn = auth.value != null;
      if (path == '/initializing') {
        final from = _safeReturnPath(state);
        return loggedIn
            ? from ?? '/docs'
            : '/login${from == null ? '' : '?from=${Uri.encodeComponent(from)}'}';
      }
      if (!loggedIn && path != '/login') {
        return '/login?from=${Uri.encodeComponent(_routeDestination(state))}';
      }
      if (loggedIn && path == '/login') {
        return _safeReturnPath(state) ?? '/docs';
      }
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
      GoRoute(path: '/', redirect: (context, state) => '/docs'),
      GoRoute(
        path: '/docs',
        builder: (context, state) => const NotesRootShell(),
      ),
      GoRoute(
        path: '/docs/:documentId',
        builder: (context, state) => NotesRootShell(
          initialDocumentId: int.tryParse(
            state.pathParameters['documentId'] ?? '',
          ),
        ),
      ),
    ],
  );
});

String _routeDestination(GoRouterState state) {
  final path = state.uri.path;
  if (path == '/login' || path == '/initializing') {
    return _safeReturnPath(state) ?? '/docs';
  }
  return state.uri.toString();
}

String? _safeReturnPath(GoRouterState state) {
  final from = state.uri.queryParameters['from'];
  if (from == null ||
      from.isEmpty ||
      !from.startsWith('/') ||
      from.startsWith('//') ||
      from.startsWith('/login') ||
      from.startsWith('/initializing')) {
    return null;
  }
  return from;
}
