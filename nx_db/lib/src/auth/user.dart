import '../core/config/backend_presets.dart';

/// User model: [preset] drives all resolved URLs via [resolve].
/// [personalDomainId] / [homeDomainId] scope KGQL calls (entered at login).
class User {
  final String userId;
  final int personalDomainId;
  final int homeDomainId;
  final BackendPreset preset;

  User({
    required this.userId,
    required this.personalDomainId,
    required this.homeDomainId,
    required this.preset,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          personalDomainId == other.personalDomainId &&
          homeDomainId == other.homeDomainId &&
          preset == other.preset;

  @override
  int get hashCode =>
      userId.hashCode ^
      personalDomainId.hashCode ^
      homeDomainId.hashCode ^
      preset.hashCode;
}

/// Fixed login choices used by the mobile apps.
class AuthLoginProfile {
  const AuthLoginProfile({
    required this.label,
    required this.userId,
    required this.personalDomainId,
    required this.homeDomainId,
  });

  final String label;
  final String userId;
  final int personalDomainId;
  final int homeDomainId;
}

const authLoginProfiles = <AuthLoginProfile>[
  AuthLoginProfile(
    label: 'Nathik',
    userId: '1',
    personalDomainId: 1,
    homeDomainId: 2,
  ),
  AuthLoginProfile(
    label: 'Yareni',
    userId: '2',
    personalDomainId: 3,
    homeDomainId: 2,
  ),
];
