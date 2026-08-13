import 'package:flutter_test/flutter_test.dart';
import 'package:nx_docs/application/ports/session_store.dart';
import 'package:nx_docs/application/session/offline_session_restorer.dart';

void main() {
  test('endpoint routes share one user cache identity', () {
    const lan = CachedSession(userId: '7', backendPreset: 'pi_lan');
    const wan = CachedSession(userId: '7', backendPreset: 'pi_wan');
    const tailscale = CachedSession(userId: '7', backendPreset: 'pi_tailscale');

    expect(
      <String>{lan.accountKey, wan.accountKey, tailscale.accountKey},
      {'user:7'},
    );
  });

  const session = CachedSession(userId: 'user-1', backendPreset: 'production');

  test(
    'cached session opens offline when the backend is unreachable',
    () async {
      final store = MemorySessionStore(session);
      final result = await OfflineSessionRestorer(
        store: store,
        probe: (_) async => SessionProbeResult.unreachable,
      ).restore();

      expect(result.mode, SessionMode.offline);
      expect(result.session!.accountKey, 'user:user-1');
      expect(await store.load(), same(session));
    },
  );

  test('timeout classification retains credentials', () async {
    final store = MemorySessionStore(session);
    await OfflineSessionRestorer(
      store: store,
      probe: (_) async => SessionProbeResult.unreachable,
    ).restore();

    expect(store.clearCalls, 0);
    expect(await store.load(), isNotNull);
  });

  test('definite authorization rejection clears credentials', () async {
    final store = MemorySessionStore(session);
    final result = await OfflineSessionRestorer(
      store: store,
      probe: (_) async => SessionProbeResult.unauthorized,
    ).restore();

    expect(result.mode, SessionMode.loginRequired);
    expect(store.clearCalls, 1);
    expect(await store.load(), isNull);
  });

  test('logout can explicitly retain downloaded data', () async {
    final store = MemorySessionStore(session);
    final erased = <String>[];
    await OfflineLogout(
      store: store,
      erasePartition: (key) async => erased.add(key),
    ).run(session: session, downloadedData: DownloadedDataLogoutPolicy.retain);

    expect(await store.load(), isNull);
    expect(erased, isEmpty);
  });

  test('logout can explicitly erase only the active partition', () async {
    final store = MemorySessionStore(session);
    final erased = <String>[];
    await OfflineLogout(
      store: store,
      erasePartition: (key) async => erased.add(key),
    ).run(session: session, downloadedData: DownloadedDataLogoutPolicy.erase);

    expect(erased, ['user:user-1']);
  });
}

class MemorySessionStore implements SessionStore {
  MemorySessionStore(this.value);

  CachedSession? value;
  var clearCalls = 0;

  @override
  Future<void> clear() async {
    clearCalls++;
    value = null;
  }

  @override
  Future<CachedSession?> load() async => value;

  @override
  Future<void> save(CachedSession session) async => value = session;
}
