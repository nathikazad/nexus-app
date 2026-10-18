import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_auth/nx_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('instant restoration is limited to the four offline applications', () {
    for (final app in [
      'nx_expense',
      'nx_books',
      'nx_cards',
      'nx_docs',
      'nx_main',
      'nx_post',
    ]) {
      final c = ProviderContainer(
        overrides: [nexusClientAppIdProvider.overrideWithValue(app)],
      );
      expect(
        c.read(restoreCachedSessionImmediatelyProvider),
        !['nx_main', 'nx_post'].contains(app),
      );
      c.dispose();
    }
  });
  setUp(
    () => SharedPreferences.setMockInitialValues({
      PrefsKeys.userId: '7',
      PrefsKeys.backendPreset: 'hosted',
      'nexus.domain.hosted.7': 2,
    }),
  );

  test(
    'saved partition opens before a stalled auth server; rejection clears it later',
    () async {
      final remote = Completer<NexusIdentity?>();
      final c = ProviderContainer(
        overrides: [
          nexusClientAppIdProvider.overrideWithValue('nx_expense'),
          retainAuthSessionWhenOfflineProvider.overrideWithValue(true),
          oidcSessionRestoreProvider.overrideWithValue(
            (_, __) => remote.future,
          ),
          domainLoaderProvider.overrideWithValue((_) async => const []),
        ],
      );
      addTearDown(c.dispose);
      final watch = Stopwatch()..start();
      final user = await c
          .read(authProvider.future)
          .timeout(const Duration(milliseconds: 500));
      expect(user?.userId, '7');
      expect(user?.domainId, 2);
      expect(watch.elapsedMilliseconds, lessThan(500));
      expect(remote.isCompleted, false);
      await Future<void>.delayed(Duration.zero);
      remote.completeError(const AuthSessionRejected());
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(c.read(authProvider).value, isNull);
      expect(
        (await SharedPreferences.getInstance()).getString(PrefsKeys.userId),
        isNull,
      );
    },
  );

  test('late validation cannot restore or clear a new selection', () async {
    final remote = Completer<NexusIdentity?>();
    final c = ProviderContainer(
      overrides: [
        nexusClientAppIdProvider.overrideWithValue('nx_expense'),
        retainAuthSessionWhenOfflineProvider.overrideWithValue(true),
        oidcSessionRestoreProvider.overrideWithValue((_, __) => remote.future),
        domainLoaderProvider.overrideWithValue(
          (_) async => const [
            DomainMembership(id: 3, name: 'Other', role: 'member'),
          ],
        ),
      ],
    );
    addTearDown(c.dispose);
    await c.read(authProvider.future);
    await Future<void>.delayed(Duration.zero);
    await c.read(authProvider.notifier).selectDomain(3);
    remote.completeError(const AuthSessionRejected());
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(c.read(authProvider).value?.domainId, 3);
    expect(
      (await SharedPreferences.getInstance()).getString(PrefsKeys.userId),
      '7',
    );
  });

  test('without a saved domain startup does not guess a partition', () async {
    SharedPreferences.setMockInitialValues({
      PrefsKeys.userId: '7',
      PrefsKeys.backendPreset: 'hosted',
    });
    final remote = Completer<NexusIdentity?>();
    final c = ProviderContainer(
      overrides: [
        nexusClientAppIdProvider.overrideWithValue('nx_expense'),
        retainAuthSessionWhenOfflineProvider.overrideWithValue(true),
        oidcSessionRestoreProvider.overrideWithValue((_, __) => remote.future),
        domainLoaderProvider.overrideWithValue((_) async => const []),
      ],
    );
    addTearDown(c.dispose);
    final future = c.read(authProvider.future);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(c.read(authProvider).isLoading, true);
    remote.complete(const NexusIdentity(userId: '7'));
    expect((await future)?.domainId, isNull);
  });
}
