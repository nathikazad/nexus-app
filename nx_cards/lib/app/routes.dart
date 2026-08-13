import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nx_cards/account/account_session.dart';
import 'package:nx_cards/account/login_page.dart';
import 'package:nx_cards/browser/browser_page.dart';
import 'package:nx_db/auth.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.onDispose(refresh.dispose);
  ref.listen(authProvider, (_, _) => refresh.value++);
  ref.listen(activeCardsSessionProvider, (_, _) => refresh.value++);
  return GoRouter(
    refreshListenable: refresh,
    initialLocation: '/browser',
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final session = ref.read(activeCardsSessionProvider);
      if (session.isLoading || (auth.isLoading && session.value == null)) {
        return state.uri.path == '/loading' ? null : '/loading';
      }
      final loggedIn = session.value != null;
      if (!loggedIn && state.uri.path != '/login') return '/login';
      if (loggedIn &&
          (state.uri.path == '/login' || state.uri.path == '/loading')) {
        return '/browser';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/loading',
        builder: (_, _) =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      GoRoute(path: '/login', builder: (_, _) => const CardsLoginScreen()),
      GoRoute(path: '/', redirect: (_, _) => '/browser'),
      GoRoute(path: '/browser', builder: (_, _) => const BrowserPage()),
    ],
  );
});
