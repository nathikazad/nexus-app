import 'package:nx_offline/nx_offline.dart' as offline;

class CachedSession {
  const CachedSession({required this.userId, required this.backendPreset})
    : assert(userId != ''),
      assert(backendPreset != '');

  final String userId;
  final String backendPreset;

  static const String serverId = 'nexus-primary';
  static const String application = 'nx_notes';

  offline.CachedSession get shared => offline.CachedSession(
    serverId: serverId,
    userId: userId,
    application: application,
    route: backendPreset,
  );

  factory CachedSession.fromShared(offline.CachedSession session) {
    if (session.serverId != serverId || session.application != application) {
      throw StateError('Cached session does not belong to Nexus Docs');
    }
    return CachedSession(userId: session.userId, backendPreset: session.route);
  }

  /// Endpoint presets are alternate routes to the same database. They must
  /// never partition a user's local cache or outbox.
  String get accountKey => 'user:$userId';
}

abstract interface class SessionStore {
  Future<CachedSession?> load();

  Future<void> save(CachedSession session);

  Future<void> clear();
}
