import 'package:nx_db/app_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_books/core/theme/app_theme.dart';
import 'package:nx_books/router.dart';
import 'package:nx_books/settings/books_preferences.dart';
import 'package:nx_books/data/providers.dart';
import 'package:nx_db/auth.dart';
import 'companion/reading_route.dart';

class NexusBooksApp extends ConsumerWidget {
  const NexusBooksApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final darkMode = ref.watch(booksDarkModeProvider);
    final router = ref.watch(routerProvider);
    final user = ref.watch(authProvider).value;
    return AppDataHost(
      session: ref.watch(booksDataSessionProvider),
      child: MaterialApp.router(
        key: ValueKey<bool>(darkMode),
        title: 'Nexus Books',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(dark: darkMode),
        routerConfig: router,
        builder: (context, child) => DomainSessionGate(
          child: ReadingCompanionHost(
            router: router,
            enabled: user?.domainId != null,
            sessionKey: user?.domainId == null ? null : user!.sessionKey,
            child: child!,
          ),
        ),
      ),
    );
  }
}
