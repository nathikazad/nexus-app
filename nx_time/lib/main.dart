import 'package:nx_time/data/domains/domain_workspace.dart';
import 'package:nx_db/person.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/riverpod.dart';
import 'package:nx_db/auth.dart';

import 'package:nx_time/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ProviderScope(
      overrides: [
        graphqlClientProvider.overrideWith((ref) {
          final w = ref.watch(timeDomainsProvider).requireValue;
          return w.clients[w.personalId]!;
        }),
        authenticatedUserProvider.overrideWith((ref) async {
          final w = await ref.watch(timeDomainsProvider.future);
          return User(
            userId: w.user.userId,
            preset: w.user.preset,
            domainId: w.personalId,
            domainName: w.name(w.personalId),
          );
        }),
        dbAuditSourceKindProvider.overrideWithValue('nx_time'),
        nexusClientAppIdProvider.overrideWithValue('nx_time'),
      ],
      child: const NexusTimeApp(),
    ),
  );
}
