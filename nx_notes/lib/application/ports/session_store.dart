class CachedSession {
  const CachedSession({required this.userId, required this.backendPreset})
    : assert(userId != ''),
      assert(backendPreset != '');

  final String userId;
  final String backendPreset;

  String get accountKey => '$backendPreset:$userId';
}

abstract interface class SessionStore {
  Future<CachedSession?> load();

  Future<void> save(CachedSession session);

  Future<void> clear();
}
