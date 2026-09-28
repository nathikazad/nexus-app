import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Non-secret binding. Tokens stay in RAM; private keys stay on the Necklace.
class NecklaceEnrollment {
  static String _key(String backend, String user) =>
      'necklace.identity.${jsonEncode([backend, user])}';
  static Future<void> save(
      String backend, String user, String remoteId, String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(backend, user),
        jsonEncode({'remote_id': remoteId, 'device_id': deviceId}));
  }

  static Future<String?> load(
      String backend, String user, String remoteId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final raw = prefs.getString(_key(backend, user));
    if (raw == null) return null;
    final value = jsonDecode(raw) as Map<String, dynamic>;
    return value['remote_id'] == remoteId
        ? value['device_id'] as String?
        : null;
  }
}
