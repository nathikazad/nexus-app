import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:nx_auth/nx_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<User?> restore({
    bool offlineAllowed = true,
    String? savedUser = '42',
    required OidcSessionRestore remote,
  }) async {
    SharedPreferences.setMockInitialValues({
      if (savedUser != null) PrefsKeys.userId: savedUser,
      PrefsKeys.backendPreset: BackendPreset.hosted.key,
    });
    final container = ProviderContainer(
      overrides: [
        domainLoaderProvider.overrideWithValue((_) async => const []),
        retainAuthSessionWhenOfflineProvider.overrideWithValue(offlineAllowed),
        nexusClientAppIdProvider.overrideWithValue('nx_books'),
        oidcSessionRestoreProvider.overrideWithValue(remote),
        authProvider.overrideWith(
          () => AuthController(initialDelay: Duration.zero),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container.read(authProvider.future);
  }

  test(
    'offline outage retains the exact saved account and preference',
    () async {
      final user = await restore(
        remote: (preset, app) async {
          expect(preset, BackendPreset.hosted);
          expect(app, 'nx_books');
          throw const AuthServiceUnavailable();
        },
      );
      expect(user?.userId, '42');
      expect(
        (await SharedPreferences.getInstance()).getString(PrefsKeys.userId),
        '42',
      );
    },
  );

  test(
    'an outage cannot create a session or opt other apps into offline access',
    () async {
      Future<NexusIdentity?> unavailable(BackendPreset _, String __) async =>
          throw const AuthServiceUnavailable();
      expect(await restore(savedUser: null, remote: unavailable), isNull);
      expect(await restore(offlineAllowed: false, remote: unavailable), isNull);
    },
  );

  test(
    'a missing OIDC session clears stale identity even with offline enabled',
    () async {
      expect(await restore(remote: (_, __) async => null), isNull);
      expect(
        (await SharedPreferences.getInstance()).getString(PrefsKeys.userId),
        isNull,
      );
    },
  );

  test('successful restoration uses the verified identity', () async {
    final user = await restore(
      remote: (_, __) async => const NexusIdentity(userId: '43'),
    );
    expect(user?.userId, '43');
  });

  test('definitive rejection removes the saved offline identity', () async {
    expect(
      await restore(remote: (_, __) async => throw const AuthSessionRejected()),
      isNull,
    );
    expect(
      (await SharedPreferences.getInstance()).getString(PrefsKeys.userId),
      isNull,
    );
  });

  test(
    'unclassified validation failures do not grant offline access',
    () async {
      expect(
        await restore(
          remote: (_, __) async =>
              throw const FormatException('invalid identity'),
        ),
        isNull,
      );
    },
  );

  test(
    'transport and server failures are unavailable; auth rejection is not',
    () async {
      for (final error in [
        TimeoutException('offline'),
        http.ClientException('unreachable'),
        http.Response('', 503),
      ]) {
        await expectLater(
          withAuthAvailability(() async => throw error),
          throwsA(isA<AuthServiceUnavailable>()),
        );
      }
      for (final error in [http.Response('', 401), http.Response('', 403)]) {
        await expectLater(
          withAuthAvailability(() async => throw error),
          throwsA(isA<AuthSessionRejected>()),
        );
      }
      for (final error in [const FormatException('bad config')]) {
        await expectLater(
          withAuthAvailability(() async => throw error),
          throwsA(same(error)),
        );
      }
    },
  );
}
