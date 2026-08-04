import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nx_cards/features/auth/cards_login_screen.dart';
import 'package:nx_cards/features/shell/cards_home.dart';
import 'package:nx_db/auth.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authProvider, (_, _) => refresh.value++);
  return GoRouter(
    refreshListenable: refresh,
    initialLocation: '/decks',
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      if (auth.isLoading) {
        return state.uri.path == '/loading' ? null : '/loading';
      }
      final loggedIn = auth.value != null;
      if (!loggedIn && state.uri.path != '/login') return '/login';
      if (loggedIn &&
          (state.uri.path == '/login' || state.uri.path == '/loading')) {
        return '/decks';
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
      GoRoute(path: '/', redirect: (_, _) => '/decks'),
      GoRoute(
        path: '/decks',
        builder: (_, _) => const CardsHome(initialTab: 0),
      ),
      GoRoute(
        path: '/today',
        builder: (_, _) => const CardsHome(initialTab: 1),
      ),
    ],
  );
});
