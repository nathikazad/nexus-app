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

  for (final unavailable in [false, true]) {
    test('Books cached startup handles unavailable=$unavailable', () async {
      final remote = Completer<NexusIdentity?>();
      final c = ProviderContainer(
        overrides: [
          nexusClientAppIdProvider.overrideWithValue('nx_books'),
          retainAuthSessionWhenOfflineProvider.overrideWithValue(true),
          oidcSessionRestoreProvider.overrideWithValue(
            (_, __) => remote.future,
          ),
          domainLoaderProvider.overrideWithValue((_) async => const []),
        ],
      );
      addTearDown(c.dispose);
      expect((await c.read(authProvider.future))?.domainId, 2);
      await Future<void>.delayed(Duration.zero);
      remote.completeError(
        unavailable
            ? const AuthServiceUnavailable()
            : const AuthSessionRejected(),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(c.read(authProvider).value?.userId, unavailable ? '7' : null);
    });
  }

  test(
    'token rejection after startup clears Books session, not its partition',
    () async {
      final events = StreamController<RejectedOidcSession>.broadcast();
      addTearDown(events.close);
      final c = ProviderContainer(
        overrides: [
          nexusClientAppIdProvider.overrideWithValue('nx_books'),
          retainAuthSessionWhenOfflineProvider.overrideWithValue(true),
          oidcSessionRejectionsProvider.overrideWithValue(events.stream),
          oidcSessionRestoreProvider.overrideWithValue(
            (_, __) async => const NexusIdentity(userId: '7'),
          ),
          domainLoaderProvider.overrideWithValue(
            (_) async => const [
              DomainMembership(id: 2, name: 'Home', role: 'member'),
            ],
          ),
        ],
      );
      addTearDown(c.dispose);
      await c.read(authProvider.future);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      events.add(const RejectedOidcSession(BackendPreset.hosted, 'nx_cards'));
      await Future<void>.delayed(Duration.zero);
      expect(c.read(authProvider).value?.userId, '7');
      events.add(const RejectedOidcSession(BackendPreset.hosted, 'nx_books'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(c.read(authProvider).value, isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(PrefsKeys.userId), isNull);
      expect(prefs.getInt('nexus.domain.hosted.7'), 2);
      expect(prefs.getString(PrefsKeys.lastUserId), '7');
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
