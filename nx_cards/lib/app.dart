import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_cards/core/theme/app_theme.dart';
import 'package:nx_cards/router.dart';

class NexusCardsApp extends ConsumerWidget {
  const NexusCardsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Recall',
      debugShowCheckedModeBanner: false,
      theme: buildRecallTheme(),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
