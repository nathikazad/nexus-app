import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_books/core/theme/app_theme.dart';
import 'package:nx_books/router.dart';
import 'package:nx_books/settings/books_preferences.dart';
import 'package:nx_books/data/providers.dart';
import 'package:nx_offline/nx_offline.dart';

class NexusBooksApp extends ConsumerWidget {
  const NexusBooksApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final darkMode = ref.watch(booksDarkModeProvider);
    return OfflineLifecycle(
      synchronize: ref.watch(booksLifecycleSyncProvider),
      onlineChanges: ref.watch(booksOnlineChangesProvider),
      child: MaterialApp.router(
        key: ValueKey<bool>(darkMode),
        title: 'Nexus Books',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(dark: darkMode),
        routerConfig: ref.watch(routerProvider),
      ),
    );
  }
}
