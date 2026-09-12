import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_books/core/theme/app_theme.dart';
import 'package:nx_books/router.dart';
import 'package:nx_books/settings/books_preferences.dart';
import 'package:nx_books/data/providers.dart';
import 'package:nx_offline/nx_offline.dart';
import 'package:nx_books/companion/reading_companion.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_documents/nx_documents.dart';
import 'companion/epub_companion_context.dart';

class NexusBooksApp extends ConsumerWidget {
  const NexusBooksApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final darkMode = ref.watch(booksDarkModeProvider);
    final router = ref.watch(routerProvider);
    final user = ref.watch(authProvider).value;
    return OfflineLifecycle(
      synchronize: ref.watch(booksLifecycleSyncProvider),
      onlineChanges: ref.watch(booksOnlineChangesProvider),
      child: MaterialApp.router(
        key: ValueKey<bool>(darkMode),
        title: 'Nexus Books',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(dark: darkMode),
        routerConfig: router,
        builder: (context, child) => ListenableBuilder(
          listenable: Listenable.merge([
            router.routeInformationProvider,
            ref.watch(epubCompanionContextProvider),
          ]),
          builder: (context, _) {
            if (user == null) return child!;
            final epub = ref.read(epubCompanionContextProvider).value;
            if (!shouldShowReadingCompanion(
              router.routeInformationProvider.value.uri,
              epub,
            )) {
              return child!;
            }
            final parts =
                router.routeInformationProvider.value.uri.pathSegments;
            final id = parts.length > 1 ? int.tryParse(parts[1]) : null;
            final identity = epub != null
                ? DocumentIdentity(id: epub.bookId, modelType: 'EpubBook')
                : id == null
                ? null
                : DocumentIdentity(
                    id: id,
                    modelType: parts.first == 'books' ? 'Book' : 'Document',
                  );
            return Overlay.wrap(
              child: ReadingCompanion(
                key: ValueKey(user.userId),
                identity: identity,
                child: child!,
              ),
            );
          },
        ),
      ),
    );
  }
}
