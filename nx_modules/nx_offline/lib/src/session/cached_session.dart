import 'package:shared_preferences/shared_preferences.dart';

import '../core/sync_models.dart';

final class CachedSession {
  const CachedSession({
    required this.serverId,
    required this.userId,
    required this.application,
    required this.route,
  }) : assert(serverId != ''),
       assert(userId != ''),
       assert(application != ''),
       assert(route != '');

  /// Stable logical database identity shared by every route preset.
  final String serverId;
  final String userId;
  final String application;
  final String route;

  AccountIdentity get account => AccountIdentity(
    serverId: serverId,
    userId: userId,
    application: application,
  );
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
    required this.serverId,
  });

  final SharedPreferences preferences;
  final String application;
  final String serverId;

  String get _prefix => 'nx_offline.$application.session';

  @override
  Future<CachedSession?> load() async {
    final route = preferences.getString('$_prefix.route');
    final userId = preferences.getString('$_prefix.user_id');
    if (route == null || route.isEmpty || userId == null || userId.isEmpty) {
      return null;
    }
    return CachedSession(
      serverId: serverId,
      userId: userId,
      application: application,
      route: route,
    );
  }

  @override
  Future<void> save(CachedSession session) async {
    if (session.application != application) {
      throw StateError('session belongs to a different application');
    }
    if (session.serverId != serverId) {
      throw StateError('session belongs to a different server');
    }
    await preferences.setString('$_prefix.route', session.route);
    await preferences.setString('$_prefix.user_id', session.userId);
  }

  @override
  Future<void> clear() async {
    await preferences.remove('$_prefix.route');
    await preferences.remove('$_prefix.user_id');
  }
}
