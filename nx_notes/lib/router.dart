import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nx_notes/features/shell/notes_root_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/notes',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        redirect: (context, state) => '/notes',
      ),
      GoRoute(
        path: '/notes',
        builder: (context, state) => const NotesRootShell(),
      ),
    ],
  );
});
