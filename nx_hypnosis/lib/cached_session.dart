import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_auth/nx_auth.dart';
import 'package:nx_offline/nx_offline.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<PreferencesCachedSessionStore> hypnosisSessionStore({
  String serverId = 'nexus-primary',
}) async => PreferencesCachedSessionStore(
  preferences: await SharedPreferences.getInstance(),
  application: 'nx_hypnosis',
  serverId: serverId,
);

/// Cache only a domain-ready session published by NX Auth.
final activeHypnosisUserProvider = FutureProvider<User?>((ref) async {
  final auth = ref.watch(authProvider);
  final user = auth.value;
  if (!AppDataPolicy.current.storesOfflineData) return user;
  final store = await hypnosisSessionStore(
    serverId: user?.preset.serverId ?? 'nexus-primary',
  );
  if (!ref.mounted) return null;
  if (user != null && user.domainId == null) return null;
  if (user != null) {
    await store.save(
      CachedSession(
        serverId: user.preset.serverId,
        userId: user.userId,
        domainId: user.requiredDomainId,
        application: 'nx_hypnosis',
        route: user.preset.key,
      ),
    );
    return user;
  }
  if (!auth.isLoading) {
    await store.clear();
    return null;
  }
  // NX Auth owns restoration, including its offline policy and domain readiness.
  return null;
});
