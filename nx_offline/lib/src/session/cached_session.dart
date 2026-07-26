import 'package:shared_preferences/shared_preferences.dart';

import '../core/sync_models.dart';

final class CachedSession {
  const CachedSession({
    required this.backend,
    required this.userId,
    required this.application,
  });

  final String backend;
  final String userId;
  final String application;

  AccountScope get account =>
      AccountScope(backend: backend, userId: userId, application: application);
}

abstract interface class CachedSessionStore {
  Future<CachedSession?> load();

  Future<void> save(CachedSession session);

  Future<void> clear();
}

final class PreferencesCachedSessionStore implements CachedSessionStore {
  PreferencesCachedSessionStore({
    required this.preferences,
    required this.application,
  });

  final SharedPreferences preferences;
  final String application;

  String get _prefix => 'nx_offline.$application.session';

  @override
  Future<CachedSession?> load() async {
    final backend = preferences.getString('$_prefix.backend');
    final userId = preferences.getString('$_prefix.user_id');
    if (backend == null ||
        backend.isEmpty ||
        userId == null ||
        userId.isEmpty) {
      return null;
    }
    return CachedSession(
      backend: backend,
      userId: userId,
      application: application,
    );
  }

  @override
  Future<void> save(CachedSession session) async {
    if (session.application != application) {
      throw StateError('session belongs to a different application');
    }
    await preferences.setString('$_prefix.backend', session.backend);
    await preferences.setString('$_prefix.user_id', session.userId);
  }

  @override
  Future<void> clear() async {
    await preferences.remove('$_prefix.backend');
    await preferences.remove('$_prefix.user_id');
  }
}
