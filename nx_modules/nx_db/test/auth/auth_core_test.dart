@Tags(['auth'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nx_db/auth.dart';

void main() {
  group('CR core db / auth / presets', () {
    test('CR11.1 buildHttpLinkDefaultHeaders includes x-user-id', () {
      final h = buildHttpLinkDefaultHeaders(
        'http://127.0.0.1:5001/graphql',
        '42',
      );
      expect(h['x-user-id'], '42');
    });

    test('CR11.2 normalizeHttpEndpoint upgrades public HTTP to HTTPS', () {
      expect(
        normalizeHttpEndpoint('http://graphql.nathikazad.com/graphql'),
        'https://graphql.nathikazad.com/graphql',
      );
    });

    test('CR11.3 BackendPreset.fromKey known keys', () {
      expect(BackendPreset.fromKey('laptop'), BackendPreset.laptop);
      expect(BackendPreset.fromKey('localhost'), BackendPreset.localhost);
      expect(BackendPreset.fromKey('pi_tailscale'), BackendPreset.piTailscale);
    });

    test('CR11.4 resolve URLs non-empty for each preset', () {
      for (final p in BackendPreset.values) {
        final u = resolve(p);
        expect(u.graphqlHttp, isNotEmpty);
        expect(u.sockWs, isNotEmpty);
        expect(u.imageHttp, isNotEmpty);
      }
    });

    test('CR11.4b Pi presets use a single Caddy origin', () {
      final u = resolve(BackendPreset.piWan);

      expect(u.graphqlHttp, 'https://nexus.nathikazad.com/graphql');
      expect(u.sockWs, 'wss://nexus.nathikazad.com/realtime');
      expect(u.imageHttp, 'https://nexus.nathikazad.com');

      final tailscale = resolve(BackendPreset.piTailscale);
      expect(tailscale.graphqlHttp, 'http://100.108.43.37/graphql');
      expect(tailscale.sockWs, 'ws://100.108.43.37/realtime');
      expect(tailscale.imageHttp, 'http://100.108.43.37');
    });

    test('standard Caddy routes derive from one origin', () {
      final urls = BackendUrls.fromOrigin('https://example.com/');

      expect(urls.graphqlHttp, 'https://example.com/graphql');
      expect(urls.sockWs, 'wss://example.com/realtime');
      expect(urls.imageHttp, 'https://example.com');
    });

    test('CR11.5 login persists prefs', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(
            () => AuthController(
              initialDelay: Duration.zero,
              skipBackendPing: true,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final err = await container
          .read(authProvider.notifier)
          .login('77', BackendPreset.laptop);
      expect(err, isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(PrefsKeys.userId), '77');
      expect(
        prefs.getString(PrefsKeys.backendPreset),
        BackendPreset.laptop.key,
      );
      expect(prefs.getString(PrefsKeys.endpoint), isNotEmpty);
      expect(prefs.getString(PrefsKeys.sockWsUrl), isNotEmpty);
    });

    test('CR11.6 logout clears prefs', () async {
      SharedPreferences.setMockInitialValues({
        PrefsKeys.userId: '1',
        PrefsKeys.endpoint: 'http://x/graphql',
        PrefsKeys.backendPreset: BackendPreset.laptop.key,
        PrefsKeys.sockWsUrl: 'ws://x',
      });
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(
            () => AuthController(
              initialDelay: Duration.zero,
              skipBackendPing: true,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authProvider.future);
      await container.read(authProvider.notifier).logout();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(PrefsKeys.userId), isNull);
      expect(prefs.getString(PrefsKeys.endpoint), isNull);
      expect(prefs.getString(PrefsKeys.backendPreset), isNull);
      expect(prefs.getString(PrefsKeys.sockWsUrl), isNull);
    });

    test('CR11.7 userIdProvider after login', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(
            () => AuthController(
              initialDelay: Duration.zero,
              skipBackendPing: true,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(authProvider.notifier)
          .login('88', BackendPreset.laptop);
      expect(container.read(userIdProvider), '88');
    });

    test('CR11.8 appStatusProvider initializing then authenticated', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(
            () => AuthController(
              initialDelay: Duration.zero,
              skipBackendPing: true,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(appStatusProvider), AppStatus.initializing);

      await container.read(authProvider.future);
      expect(container.read(appStatusProvider), AppStatus.unauthenticated);

      await container
          .read(authProvider.notifier)
          .login('1', BackendPreset.laptop);
      expect(container.read(appStatusProvider), AppStatus.authenticated);
    });

    test('CR11.9 restore does not require domain prefs', () async {
      SharedPreferences.setMockInitialValues({
        PrefsKeys.userId: '1',
        PrefsKeys.endpoint: 'http://x/graphql',
        PrefsKeys.backendPreset: BackendPreset.laptop.key,
        PrefsKeys.sockWsUrl: 'ws://x',
      });
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(
            () => AuthController(
              initialDelay: Duration.zero,
              skipBackendPing: true,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authProvider.future);
      expect(container.read(userIdProvider), '1');
    });

    test('CR11.10 offline auth restore is opt-in application policy', () {
      final onlineOnly = ProviderContainer();
      final offlineNative = ProviderContainer(
        overrides: [
          retainAuthSessionWhenOfflineProvider.overrideWithValue(true),
        ],
      );
      addTearDown(onlineOnly.dispose);
      addTearDown(offlineNative.dispose);

      expect(onlineOnly.read(retainAuthSessionWhenOfflineProvider), isFalse);
      expect(offlineNative.read(retainAuthSessionWhenOfflineProvider), isTrue);
    });
  });
}
