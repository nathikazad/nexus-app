import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nx_books/features/auth/books_login_screen.dart';
import 'package:nx_books/features/books/books_shell.dart';
import 'package:nx_books/features/books/notes/book_notes_page.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_documents/nx_documents.dart';
import 'companion/reading_route.dart';
import 'epub/epub_route_page.dart';

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
      ReadingRoute(
        path: '/books/:bookId/notes',
        readingIdentity: (state) => _readingIdentity(state, 'bookId', 'Book'),
        builder: (context, state) {
          final bookId = int.tryParse(state.pathParameters['bookId'] ?? '');
          if (bookId == null) return const BooksRootShell();
          return BookNotesPage(bookId: bookId);
        },
      ),
      GoRoute(
        path: '/books/:bookId/details',
        builder: (context, state) {
          final bookId = int.tryParse(state.pathParameters['bookId'] ?? '');
          if (bookId == null) return const BooksRootShell();
          return BookDetailPage(bookId: bookId);
        },
      ),
      ReadingRoute(
        path: '/documents/:documentId/notes',
        readingIdentity: (state) =>
            _readingIdentity(state, 'documentId', 'Document'),
        builder: (context, state) {
          final documentId = int.tryParse(
            state.pathParameters['documentId'] ?? '',
          );
          if (documentId == null) return const BooksRootShell();
          return DocumentNotesPage(documentId: documentId);
        },
      ),
      ReadingRoute(
        path: '/books/:bookId/reader',
        isEpub: true,
        readingIdentity: (state) => _epubRequest(state) == null
            ? null
            : _readingIdentity(state, 'bookId', 'EpubBook'),
        builder: (context, state) {
          final request = _epubRequest(state);
          if (request == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Book reader')),
              body: const Center(
                child: Text('Open this EPUB from its book summary.'),
              ),
            );
          }
          // The stable reader host renders this route while retaining its
          // renderer across pops. The route remains the source of visibility.
          return const SizedBox.expand();
        },
      ),
    ],
  );
});

DocumentIdentity? _readingIdentity(
  GoRouterState state,
  String parameter,
  String modelType,
) {
  final id = int.tryParse(state.pathParameters[parameter] ?? '');
  return id == null ? null : DocumentIdentity(id: id, modelType: modelType);
}

EpubRouteRequest? _epubRequest(GoRouterState state) {
  final request = state.extra;
  return request is EpubRouteRequest &&
          request.book.id.toString() == state.pathParameters['bookId']
      ? request
      : null;
}

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
