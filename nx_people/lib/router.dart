import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nx_people/features/shell/people_root_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/people',
    routes: <RouteBase>[
      GoRoute(path: '/', redirect: (context, state) => '/people'),
      GoRoute(
        path: '/people',
        builder: (context, state) => const PeopleRootShell(),
      ),
    ],
  );
});
