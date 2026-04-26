import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nx_cooking/features/recipe_detail/recipe_detail_page.dart';
import 'package:nx_cooking/features/shell/cooking_shell.dart';

/// UI-only: no auth redirects. PGDB wiring can add guards later.
final Provider<GoRouter> goRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: false,
    routes: [
      GoRoute(path: '/', builder: (context, state) => const CookingShell()),
      GoRoute(
        path: '/recipe/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return RecipeDetailPage(recipeId: id);
        },
      ),
    ],
  );
});
