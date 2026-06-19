import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_notes/core/theme/app_theme.dart';
import 'package:nx_notes/router.dart';

class NexusNotesApp extends ConsumerWidget {
  const NexusNotesApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(appDarkModeProvider);
    AppColors.isDark = isDark;
    return MaterialApp.router(
      key: ValueKey<bool>(isDark),
      title: 'Nexus Notes',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      localizationsDelegates: const [
        AppFlowyEditorLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppFlowyEditorLocalizations.delegate.supportedLocales,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
