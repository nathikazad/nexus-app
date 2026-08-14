import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_cards/app/routes.dart';
import 'package:nx_cards/app/theme.dart';
import 'package:nx_cards/settings/appearance.dart';

class NexusCardsApp extends ConsumerWidget {
  const NexusCardsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance =
        ref.watch(appearanceProvider).value ?? AppAppearance.system;
    return MaterialApp.router(
      title: 'Recall',
      debugShowCheckedModeBanner: false,
      theme: buildRecallTheme(),
      darkTheme: buildRecallDarkTheme(),
      themeMode: appearance.themeMode,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
