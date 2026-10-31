import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_time/data/domains/domain_workspace.dart';
import 'package:nx_time/features/settings/settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsAuth extends AuthController {
  @override
  Future<User?> build() async =>
      User(userId: '1', preset: BackendPreset.localhost);
}

void main() {
  testWidgets('Settings switches to one domain and exposes Colors and Logout', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(SettingsAuth.new),
        domainLoaderProvider.overrideWithValue(
          (_) async => const [
            DomainMembership(
              id: 1,
              name: 'Personal',
              role: 'owner',
              kind: 'personal',
            ),
            DomainMembership(
              id: 2,
              name: 'Home',
              role: 'member',
              kind: 'shared',
            ),
          ],
        ),
        timeSessionFactoryProvider.overrideWithValue((_, __, ___) => null),
        timeDomainClientFactoryProvider.overrideWithValue(
          (_, id) => GraphQLClient(
            cache: GraphQLCache(),
            link: Link.function((request, [forward]) => const Stream.empty()),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(timeDomainsProvider.future);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SettingsPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Personal'), findsOneWidget);
    expect(find.text('Colors'), findsOneWidget);
    expect(find.text('Logout'), findsOneWidget);
    expect(find.text('Domain appearance'), findsNothing);
    await tester.tap(find.text('Domain'));
    await tester.pumpAndSettle();
    expect(find.byType(CheckboxListTile), findsNothing);
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    final selected = await container.read(timeDomainsProvider.future);
    expect(selected.selectedIds, {2});
    expect(selected.clients.keys, [2]);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Personal'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
