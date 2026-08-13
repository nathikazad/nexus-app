import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nx_offline/nx_offline.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const session = CachedSession(
    serverId: 'production',
    userId: 'user-1',
    application: 'test',
    route: 'pi_wan',
  );

  test('network routes do not change the account identity', () {
    const lan = CachedSession(
      serverId: 'nexus-primary',
      userId: 'user-1',
      application: 'notes',
      route: 'pi_lan',
    );
    const wan = CachedSession(
      serverId: 'nexus-primary',
      userId: 'user-1',
      application: 'notes',
      route: 'pi_wan',
    );
    const tailscale = CachedSession(
      serverId: 'nexus-primary',
      userId: 'user-1',
      application: 'notes',
      route: 'pi_tailscale',
    );

    expect(lan.account, wan.account);
    expect(wan.account, tailscale.account);
    expect(lan.account.key, 'notes:nexus-primary:user-1');
  });

  test('preferences store partitions cached sessions by application', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final first = PreferencesCachedSessionStore(
      preferences: preferences,
      application: 'time',
      serverId: 'nexus-primary',
    );
    final second = PreferencesCachedSessionStore(
      preferences: preferences,
      application: 'expense',
      serverId: 'nexus-primary',
    );

    await first.save(
      const CachedSession(
        serverId: 'nexus-primary',
        userId: 'user-1',
        application: 'time',
        route: 'pi_wan',
      ),
    );

    expect((await first.load())?.userId, 'user-1');
    expect(await second.load(), isNull);
  });

  test('unreachable backend opens cached session offline', () async {
    final store = _MemorySessionStore(session);
    final result = await OfflineSessionRestorer(
      store: store,
      probe: (_) async => SessionProbeResult.unreachable,
    ).restore();

    expect(result.mode, SessionMode.offline);
    expect(result.session, same(session));
    expect(store.cleared, isFalse);
  });

  test('authorization rejection clears cached session', () async {
    final store = _MemorySessionStore(session);
    final result = await OfflineSessionRestorer(
      store: store,
      probe: (_) async => SessionProbeResult.unauthorized,
    ).restore();

    expect(result.mode, SessionMode.loginRequired);
    expect(result.session, isNull);
    expect(store.cleared, isTrue);
  });

  test('HTTP probe distinguishes authorization from reachability', () async {
    final unauthorized = HttpSessionProbe(
      endpointFor: (_) => Uri.parse('https://example.test/graphql'),
      headersFor: (_) => {'X-User-ID': 'user-1'},
      client: MockClient((request) async {
        expect(request.headers['X-User-ID'], 'user-1');
        return http.Response('', 401);
      }),
    );
    final unavailable = HttpSessionProbe(
      endpointFor: (_) => Uri.parse('https://example.test/graphql'),
      headersFor: (_) => {},
      client: MockClient((_) async => http.Response('', 503)),
    );

    expect(await unauthorized.call(session), SessionProbeResult.unauthorized);
    expect(await unavailable.call(session), SessionProbeResult.unreachable);
  });

  test('logout can erase only the selected account partition', () async {
    final store = _MemorySessionStore(session);
    String? erased;
    await OfflineLogout(
      store: store,
      erasePartition: (accountKey) async => erased = accountKey,
    ).run(session: session, downloadedData: DownloadedDataLogoutPolicy.erase);

    expect(store.cleared, isTrue);
    expect(erased, session.account.key);
  });
}

final class _MemorySessionStore implements CachedSessionStore {
  _MemorySessionStore(this.value);

  CachedSession? value;
  bool cleared = false;

  @override
  Future<void> clear() async {
    cleared = true;
    value = null;
  }

  @override
  Future<CachedSession?> load() async => value;

  @override
  Future<void> save(CachedSession session) async => value = session;
}
