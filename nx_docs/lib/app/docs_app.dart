import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_docs/app/theme.dart';
import 'package:nx_docs/documents/editor/document_text_scale.dart';
import 'package:nx_docs/app/routes.dart';

class NexusDocsApp extends ConsumerWidget {
  const NexusDocsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(appDarkModeProvider);
    AppColors.isDark = isDark;
    return MaterialApp.router(
      key: ValueKey<bool>(isDark),
      title: 'Nexus Docs',
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
      builder: (context, child) =>
          DocumentTextScaleShortcuts(child: child ?? const SizedBox.shrink()),
    );
  }
}
