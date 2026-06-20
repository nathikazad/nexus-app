import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nx_books/features/auth/books_login_screen.dart';
import 'package:nx_books/features/books/books_shell.dart';
import 'package:nx_db/auth.dart';

class BooksInitializingScreen extends StatelessWidget {
  const BooksInitializingScreen({super.key});

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
    initialLocation: '/books',
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
            ? from ?? '/books'
            : '/login${from == null ? '' : '?from=${Uri.encodeComponent(from)}'}';
      }
      if (!loggedIn && path != '/login') {
        return '/login?from=${Uri.encodeComponent(_routeDestination(state))}';
      }
      if (loggedIn && path == '/login') {
        return _safeReturnPath(state) ?? '/books';
      }
      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: '/login',
        builder: (context, state) => const BooksLoginScreen(),
      ),
      GoRoute(
        path: '/initializing',
        builder: (context, state) => const BooksInitializingScreen(),
      ),
      GoRoute(path: '/', redirect: (context, state) => '/books'),
      GoRoute(
        path: '/books',
        builder: (context, state) => const BooksRootShell(),
      ),
    ],
  );
});

String _routeDestination(GoRouterState state) {
  final path = state.uri.path;
  if (path == '/login' || path == '/initializing') {
    return _safeReturnPath(state) ?? '/books';
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
