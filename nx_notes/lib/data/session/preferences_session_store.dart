import 'package:nx_notes/application/ports/session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreferencesSessionStore implements SessionStore {
  PreferencesSessionStore(this.preferences);

  static const String userIdKey = 'nx_notes.offline_session.user_id';
  static const String backendPresetKey =
      'nx_notes.offline_session.backend_preset';

  final SharedPreferences preferences;

  @override
  Future<CachedSession?> load() async {
    final userId = preferences.getString(userIdKey);
    final preset = preferences.getString(backendPresetKey);
    if (userId == null || userId.isEmpty || preset == null || preset.isEmpty) {
      return null;
    }
    return CachedSession(userId: userId, backendPreset: preset);
  }

  @override
  Future<void> save(CachedSession session) async {
    await preferences.setString(userIdKey, session.userId);
    await preferences.setString(backendPresetKey, session.backendPreset);
  }

  @override
  Future<void> clear() async {
    await preferences.remove(userIdKey);
    await preferences.remove(backendPresetKey);
  }
}
