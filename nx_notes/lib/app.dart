import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_notes/core/theme/app_theme.dart';
import 'package:nx_notes/router.dart';

class NexusNotesApp extends ConsumerWidget {
  const NexusNotesApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Nexus Notes',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
