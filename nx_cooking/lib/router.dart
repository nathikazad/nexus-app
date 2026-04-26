import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nx_cooking/features/recipe_create/recipe_create_page.dart';
import 'package:nx_cooking/features/recipe_detail/recipe_view_page.dart';
import 'package:nx_cooking/features/recipe_edit/recipe_edit_page.dart';
import 'package:nx_cooking/features/shell/cooking_shell.dart';

/// UI-only: no auth redirects. PGDB wiring can add guards later.
final Provider<GoRouter> goRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: false,
    routes: [
      GoRoute(path: '/', builder: (context, state) => const CookingShell()),
      GoRoute(
        path: '/recipe/new',
        builder: (context, state) => const RecipeCreatePage(),
      ),
      GoRoute(
        path: '/recipe/:id/edit',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return RecipeEditPage(recipeId: id);
        },
      ),
      GoRoute(
        path: '/recipe/:id',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return RecipeViewPage(recipeId: id);
        },
      ),
    ],
  );
});
