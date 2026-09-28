import 'package:nx_db/app_session.dart';
import 'package:nx_people/data/sync/people_sync_providers.dart';
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
        return DomainSessionGate(child: _PeopleDataHost(child: child!));
      },
      routerConfig: ref.watch(routerProvider),
    );
  }
}

class _PeopleDataHost extends ConsumerWidget {
  const _PeopleDataHost({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      AppDataHost(session: ref.watch(peopleDataSessionProvider), child: child);
}
