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
  if (user != null && user.domainId == null) return null;
  if (user != null) {
    final session = CachedSession(
      userId: user.userId,
      domainId: user.requiredDomainId,
      backendPreset: user.preset.key,
    );
    await store.save(session);
    return session;
  }
  return null;
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
