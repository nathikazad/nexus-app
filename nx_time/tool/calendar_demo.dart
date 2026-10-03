// Local simulator entrypoint. Never used by production main.dart.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/kgql.dart';
import 'package:nx_db/riverpod.dart';
import 'package:nx_db/person.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_time/core/theme/app_theme.dart';
import 'package:nx_time/data/domains/domain_workspace.dart';
import 'package:nx_time/features/domains/time_domain_gate.dart';
import 'package:nx_time/features/shell/app_shell.dart';

class DemoAuth extends AuthController {
  @override
  Future<User?> build() async => User(
    userId: '3',
    preset: BackendPreset.localhost,
    domainId: 3,
    domainName: 'Personal',
  );
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (const bool.fromEnvironment('dart.vm.product'))
    throw StateError('Demo is debug-only');
  runApp(
    ProviderScope(
      overrides: [
        authProvider.overrideWith(DemoAuth.new),
        domainLoaderProvider.overrideWithValue(
          (user) async => const [
            DomainMembership(
              id: 3,
              name: 'Personal',
              role: 'owner',
              kind: 'personal',
            ),
            DomainMembership(
              id: 1,
              name: 'Home',
              role: 'member',
              kind: 'shared',
            ),
          ],
        ),
        timeDomainClientFactoryProvider.overrideWithValue(
          (user, id) => createClient(
            'http://127.0.0.1:55440/graphql',
            user.userId,
            domainId: id,
          ),
        ),
        authenticatedUserProvider.overrideWith((ref) async {
          final w = await ref.watch(timeDomainsProvider.future);
          return User(
            userId: w.user.userId,
            preset: w.user.preset,
            domainId: w.personalId,
            domainName: w.name(w.personalId),
          );
        }),
        graphqlClientProvider.overrideWith((ref) {
          final w = ref.watch(timeDomainsProvider).requireValue;
          return w.clients[w.personalId]!;
        }),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const TimeDomainGate(child: AppShell()),
      ),
    ),
  );
}
