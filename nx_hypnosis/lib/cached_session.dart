import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_auth/nx_auth.dart';
import 'package:nx_offline/nx_offline.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<PreferencesCachedSessionStore> hypnosisSessionStore() async =>
    PreferencesCachedSessionStore(
      preferences: await SharedPreferences.getInstance(),
      application: 'nx_hypnosis',
      serverId: 'nexus-primary',
    );

/// Open the saved account while network authentication restores in background.
/// A completed sign-out or rejected session clears this shortcut.
final activeHypnosisUserProvider = FutureProvider<User?>((ref) async {
  final auth = ref.watch(authProvider);
  final user = auth.value;
  if (!AppDataPolicy.current.storesOfflineData) return user;
  final store = await hypnosisSessionStore();
  if (!ref.mounted) return null;
  if (user != null) {
    await store.save(
      CachedSession(
        serverId: 'nexus-primary',
        userId: user.userId,
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
  final saved = await store.load();
  final preset = BackendPreset.fromKey(saved?.route);
  return saved == null || preset == null
      ? null
      : User(userId: saved.userId, preset: preset);
});
