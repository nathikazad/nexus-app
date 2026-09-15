import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/nx_db.dart';
import 'package:nx_offline/nx_offline.dart' as offline;
import 'package:shared_preferences/shared_preferences.dart';

/// Native builds retain an account-scoped session for offline access.
final cardsOfflineEnabledProvider = Provider<bool>(
  (ref) => offline.AppDataPolicy.current.storesOfflineData,
);

final activeCardsSessionProvider = FutureProvider<offline.CachedSession?>((
  ref,
) async {
  final user = ref.watch(authProvider).value;
  if (!ref.watch(cardsOfflineEnabledProvider)) {
    if (user == null || user.domainId == null) return null;
    return offline.CachedSession(
      serverId: user.preset.serverId,
      userId: user.userId,
      domainId: user.requiredDomainId,
      application: 'nx_cards',
      route: user.preset.key,
    );
  }

  final preferences = await SharedPreferences.getInstance();
  final store = offline.PreferencesCachedSessionStore(
    preferences: preferences,
    application: 'nx_cards',
    serverId: user?.preset.serverId ?? 'nexus-primary',
  );
  if (user != null && user.domainId == null) return null;
  if (user != null) {
    final session = offline.CachedSession(
      serverId: user.preset.serverId,
      userId: user.userId,
      domainId: user.requiredDomainId,
      application: 'nx_cards',
      route: user.preset.key,
    );
    await store.save(session);
    return session;
  }

  return null;
});

Future<void> clearCardsCachedSession() async {
  final preferences = await SharedPreferences.getInstance();
  await offline.PreferencesCachedSessionStore(
    preferences: preferences,
    application: 'nx_cards',
    serverId: 'nexus-primary',
  ).clear();
}
