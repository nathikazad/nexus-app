import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nx_auth/nx_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const personal = DomainMembership(id: 1, name: 'Personal', role: 'owner');
  const shared = DomainMembership(id: 2, name: 'Home', role: 'member');
  Future<ProviderContainer> restore(
    DomainLoader loader, {
    int? saved,
    bool offline = false,
  }) async {
    SharedPreferences.setMockInitialValues({
      PrefsKeys.userId: '7',
      PrefsKeys.backendPreset: BackendPreset.localhost.key,
      if (saved != null) 'nexus.domain.localhost.7': saved,
    });
    final c = ProviderContainer(
      overrides: [
        authProvider.overrideWith(
          () => AuthController(initialDelay: Duration.zero),
        ),
        domainLoaderProvider.overrideWithValue(loader),
        retainAuthSessionWhenOfflineProvider.overrideWithValue(offline),
      ],
    );
    addTearDown(c.dispose);
    await c.read(authProvider.future);
    return c;
  }

  test('one membership auto-selects; multiple require selection', () async {
    final one = await restore((_) async => [personal]);
    expect(one.read(authProvider).value?.domainId, 1);
    final many = await restore((_) async => [personal, shared]);
    expect(many.read(authProvider).value?.domainId, isNull);
    await many.read(authProvider.notifier).selectDomain(2);
    expect(many.read(authProvider).value?.domainId, 2);
    expect(
      (await SharedPreferences.getInstance()).getInt(
        'nexus.domain.localhost.7',
      ),
      2,
    );
    many.read(authProvider.notifier).clearDomain();
    expect(many.read(authProvider).value?.domainId, isNull);
  });
  test('restores only an available membership', () async {
    final c = await restore((_) async => [personal, shared], saved: 2);
    expect(c.read(authProvider).value?.domainId, 2);
    final revoked = await restore((_) async => [personal], saved: 2);
    expect(revoked.read(authProvider).value?.domainId, 1);
  });
  test('offline restoration differs from authentication rejection', () async {
    final offline = await restore(
      (_) async => throw const AuthServiceUnavailable(),
      saved: 2,
      offline: true,
    );
    expect(offline.read(authProvider).value?.domainId, 2);
    final denied = await restore(
      (_) async => throw const AuthSessionRejected(),
      saved: 2,
      offline: true,
    );
    expect(denied.read(authProvider).value, isNull);
  });
  test(
    'an old selection response cannot resurrect a signed-out session',
    () async {
      final response = Completer<List<DomainMembership>>();
      var calls = 0;
      final c = await restore(
        (_) =>
            ++calls == 1 ? Future.value([personal, shared]) : response.future,
      );
      final pending = c.read(authProvider.notifier).selectDomain(2);
      await c.read(authProvider.notifier).logout();
      response.complete([personal, shared]);
      await pending;
      expect(c.read(authProvider).value, isNull);
    },
  );
  test(
    'token refresh retries preserve domain; caller cannot override it',
    () async {
      var requests = 0;
      final client = NexusAuthenticatedClient(
        preset: BackendPreset.hosted,
        userId: '7',
        domainId: 2,
        authHeaders: (_) async => {'authorization': 'Bearer test'},
        inner: MockClient((request) async {
          expect(request.headers['x-nexus-domain-id'], '2');
          return http.Response('', ++requests == 1 ? 401 : 200);
        }),
      );
      addTearDown(client.close);
      expect(
        (await client.get(
          Uri.parse('https://example.invalid/data'),
          headers: {'x-nexus-domain-id': '1'},
        )).statusCode,
        200,
      );
      expect(requests, 2);
    },
  );
}
