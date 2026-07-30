class CachedSession {
  const CachedSession({required this.userId, required this.backendPreset})
    : assert(userId != ''),
      assert(backendPreset != '');

  final String userId;
  final String backendPreset;

  /// Endpoint presets are alternate routes to the same database. They must
  /// never partition a user's local cache or outbox.
  String get accountKey => 'user:$userId';
}

abstract interface class SessionStore {
  Future<CachedSession?> load();

  Future<void> save(CachedSession session);

  Future<void> clear();
}
