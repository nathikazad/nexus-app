import 'package:flutter/widgets.dart';
import 'package:nx_data/nx_data.dart';
import 'package:nx_offline/nx_offline.dart';
import 'package:nx_people/data/sync/people_sync_providers.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_people/app.dart';
import 'package:nx_people/data/auth/people_auth_controller.dart';
import 'package:nx_people/data/providers.dart';
import 'package:nx_people/data/fake_people_repository.dart';
import 'package:nx_people/features/shell/people_state.dart';

class TestAuth extends PeopleAuthController {
  TestAuth(this.ready);
  final Completer<User?> ready;
  @override
  Future<User?> build() => ready.future;
  void useDomain(int? id) => state = AsyncData(
    User(userId: '1', preset: BackendPreset.hosted, domainId: id),
  );
  @override
  Future<void> selectDomain(int id) async => useDomain(id);
}

class RecordingOfflineSync implements OfflineSyncBackend {
  final reasons = <SyncReason>[];
  @override
  Future<void> synchronize(SyncReason reason) async => reasons.add(reason);
}

void main() {
  testWidgets(
    'foreground checks freshness and retries offline writes without a socket hint',
    (tester) async {
      var freshnessChecks = 0;
      final offline = RecordingOfflineSync();
      final session = AppDataSession(
        definition: AppDataDefinition(
          name: 'people',
          refreshVisible: () async {},
        ),
        checkFreshness: (refresh) async {
          freshnessChecks++;
          await refresh();
        },
        offline: offline,
        policy: const AppDataPolicy(isWeb: false),
      );
      final ready = Completer<User?>()
        ..complete(
          User(userId: '1', preset: BackendPreset.hosted, domainId: 1),
        );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            peopleDataSessionProvider.overrideWithValue(session),
            peopleOfflineStoreProvider.overrideWithValue(null),
            authProvider.overrideWith(() => TestAuth(ready)),
            peopleRepositoryProvider.overrideWithValue(FakePeopleRepository()),
          ],
          child: const NexusPeopleApp(),
        ),
      );
      await tester.pumpAndSettle();
      final startupChecks = freshnessChecks;
      expect(startupChecks, greaterThan(0));
      offline.reasons.clear();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 35));
      expect(freshnessChecks, startupChecks);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(freshnessChecks, startupChecks + 1);
      expect(offline.reasons, [SyncReason.appResumed]);
      await tester.pumpWidget(const SizedBox.shrink());
      await session.close();
    },
  );

  testWidgets('no data access during restoration or before domain selection', (
    tester,
  ) async {
    final ready = Completer<User?>();
    final auth = TestAuth(ready);
    var repositoryBuilds = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          peopleDataSessionProvider.overrideWithValue(null),
          peopleOfflineStoreProvider.overrideWithValue(null),
          authProvider.overrideWith(() => auth),
          domainLoaderProvider.overrideWithValue(
            (_) async => [
              const DomainMembership(id: 1, name: 'Personal', role: 'owner'),
              const DomainMembership(id: 2, name: 'Home', role: 'member'),
            ],
          ),
          peopleRepositoryProvider.overrideWith((ref) {
            repositoryBuilds++;
            return FakePeopleRepository();
          }),
        ],
        child: const NexusPeopleApp(),
      ),
    );
    await tester.pump();
    expect(repositoryBuilds, 0);
    ready.complete(User(userId: '1', preset: BackendPreset.hosted));
    await tester.pumpAndSettle();
    expect(find.text('Choose a domain'), findsOneWidget);
    expect(repositoryBuilds, 0);
    await tester.tap(find.text('Personal'));
    await tester.pumpAndSettle();
    expect(repositoryBuilds, 1);
    expect(find.text('Choose a domain'), findsNothing);
    auth.useDomain(null);
    await tester.pumpAndSettle();
    expect(find.text('Choose a domain'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('workspace selection and search reset when domain changes', () async {
    final ready = Completer<User?>();
    final auth = TestAuth(ready);
    final container = ProviderContainer(
      overrides: [
        peopleDataSessionProvider.overrideWithValue(null),
        peopleOfflineStoreProvider.overrideWithValue(null),
        authProvider.overrideWith(() => auth),
      ],
    );
    addTearDown(container.dispose);
    ready.complete(
      User(userId: '1', preset: BackendPreset.hosted, domainId: 1),
    );
    await container.read(authProvider.future);
    final workspace = container.read(peopleWorkspaceProvider.notifier);
    workspace.openPerson(123);
    workspace.setSearchText('private contact');
    auth.useDomain(2);
    expect(container.read(peopleWorkspaceProvider).activePersonId, isNull);
    expect(container.read(peopleWorkspaceProvider).searchText, isEmpty);
  });
}
