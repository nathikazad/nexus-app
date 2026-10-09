/// Only fresh notifications for this signed-in user may pulse the necklace.
/// No reconnect queue: old alerts must not buzz later when Bluetooth returns.
class PushHaptics {
  PushHaptics(
      {required this.userId, required this.pulse, DateTime Function()? now})
      : now = now ?? DateTime.now;
  final String userId;
  final Future<bool> Function() pulse;
  final DateTime Function() now;
  final Set<String> _seen = {};

  Future<bool> receive(dynamic value) async {
    if (value is! Map ||
        value['app'] != 'nx_main' ||
        value['user_id'] != userId ||
        value['necklace'] != true) return false;
    // Older server notifications lacked target and used the necklace flag alone.
    final target = value['target'];
    if (target != null && target != 'both' && target != 'necklace')
      return false;
    final id = value['id'];
    final sent = value['sent_at'];
    if (id is! String || id.isEmpty || id.length > 100 || sent is! int)
      return false;
    final age = now().millisecondsSinceEpoch ~/ 1000 - sent;
    if (age < -30 || age > 60 || !_seen.add(id)) return false;
    if (_seen.length > 128) _seen.remove(_seen.first);
    try {
      return await pulse().timeout(const Duration(seconds: 15));
    } catch (_) {
      return false;
    }
  }
}
