import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nx_db/nx_db.dart';

import 'screens/debug_expense_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authProvider, (_, __) => refresh.value++);

  return GoRouter(
    refreshListenable: refresh,
    initialLocation: '/login',
    redirect: (context, state) {
      final user = ref.read(authProvider).value;
      final path = state.uri.path;
      if (user == null && path != '/login') {
        return '/login';
      }
      if (user != null && path == '/login') {
        return '/debug';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/debug',
        builder: (context, state) => const DebugExpenseScreen(),
      ),
    ],
  );
});
