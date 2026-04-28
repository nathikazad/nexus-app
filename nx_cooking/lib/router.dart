import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nx_cooking/features/auth/cooking_login_screen.dart';
import 'package:nx_cooking/features/cooking_task/cooking_task_view_page.dart';
import 'package:nx_cooking/features/recipe_detail/recipe_view_page.dart';
import 'package:nx_cooking/features/recipe_edit/recipe_edit_page.dart';
import 'package:nx_cooking/features/shell/cooking_shell.dart';
import 'package:nx_cooking/features/tag/tag_system_form_page.dart';
import 'package:nx_cooking/features/tag/tag_systems_page.dart';
import 'package:nx_db/auth.dart';

/// Auth-gated router. Mirrors nx_time: wait for auth restore, then keep PGDB
/// routes behind `/login` so providers do not fall back to default endpoints.
final Provider<GoRouter> goRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.onDispose(refresh.dispose);
  ref.listen(authProvider, (_, __) => refresh.value++);

  return GoRouter(
    refreshListenable: refresh,
    initialLocation: '/',
    debugLogDiagnostics: false,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      if (auth.isLoading) return null;

      final signedIn = auth.value != null;
      final path = state.uri.path;
      final onLogin = path == '/login';

      if (!signedIn && !onLogin) return '/login';
      if (signedIn && onLogin) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const CookingLoginScreen(),
      ),
      GoRoute(path: '/', builder: (context, state) => const CookingShell()),
      GoRoute(
        path: '/task/:id',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return CookingTaskViewPage(taskId: id);
        },
      ),
      GoRoute(
        path: '/recipe/:id',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return RecipeViewPage(recipeId: id);
        },
      ),
      GoRoute(
        path: '/recipe/:id/edit',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return RecipeEditPage(recipeId: id);
        },
      ),
      GoRoute(
        path: '/tag-systems',
        builder: (context, state) => const TagSystemsScreen(),
      ),
      GoRoute(
        path: '/tag-system/form',
        builder: (context, state) => const TagSystemFormScreen(),
      ),
      GoRoute(
        path: '/tag-system/form/:id',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return TagSystemFormScreen(tagSystemId: id);
        },
      ),
    ],
  );
});
