import '../core/config/backend_presets.dart';

/// User model: [preset] drives all resolved URLs via [resolve].
class User {
  final String userId;
  final BackendPreset preset;

  User({required this.userId, required this.preset});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          preset == other.preset;

  @override
  int get hashCode => userId.hashCode ^ preset.hashCode;
}
