import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_docs/account/account_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

final activeOfflineSessionProvider = FutureProvider<CachedSession?>((
  ref,
) async {
  final preferences = await SharedPreferences.getInstance();
  final store = PreferencesSessionStore(preferences);
  final auth = ref.watch(authProvider);
  final user = auth.value;
  if (user != null) {
    final session = CachedSession(
      userId: user.userId,
      backendPreset: user.preset.key,
    );
    await store.save(session);
    return session;
  }
  final cached = await store.load();
  if (cached == null) return null;
  final probe = HttpSessionProbe();
  ref.onDispose(probe.close);
  final result = await OfflineSessionRestorer(
    store: store,
    probe: probe.call,
  ).restore();
  return result.session;
});

typedef AccountLogoutAction = Future<void> Function();

final accountLogoutProvider = Provider<AccountLogoutAction>((ref) {
  return () async {
    final preferences = await SharedPreferences.getInstance();
    await AccountLogoutService(
      sessionStore: PreferencesSessionStore(preferences),
      logoutAuthentication: ref.read(authProvider.notifier).logout,
      invalidateOfflineSession: () {
        ref.invalidate(activeOfflineSessionProvider);
      },
    ).logout();
  };
});
