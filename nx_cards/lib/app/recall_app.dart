import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_cards/app/routes.dart';
import 'package:nx_cards/app/theme.dart';

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
