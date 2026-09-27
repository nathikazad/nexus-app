import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_people/core/theme/app_theme.dart';
import 'package:nx_people/router.dart';

class NexusPeopleApp extends ConsumerWidget {
  const NexusPeopleApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Nexus People',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      builder: (context, child) {
        if (ref.watch(authProvider).isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return DomainSessionGate(child: child!);
      },
      routerConfig: ref.watch(routerProvider),
    );
  }
}
