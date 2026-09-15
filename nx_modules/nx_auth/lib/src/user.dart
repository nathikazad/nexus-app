import 'backend_presets.dart';

/// User model: [preset] drives all resolved URLs via [resolve].
class User {
  final String userId;
  final BackendPreset preset;

  final int? domainId;
  final String? domainName;
  User({
    required this.userId,
    required this.preset,
    this.domainId,
    this.domainName,
  });
  int get requiredDomainId =>
      domainId ?? (throw StateError('Select a domain first'));
  String get storageKey =>
      '${preset.serverId}:$userId:domain:$requiredDomainId';
  String get sessionKey => '${preset.key}:$storageKey';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          preset == other.preset &&
          domainId == other.domainId;

  @override
  int get hashCode => Object.hash(userId, preset, domainId);
}

/// Fixed login choices used by direct Pi/development deployments.
class AuthLoginProfile {
  const AuthLoginProfile({required this.label, required this.userId});

  final String label;
  final String userId;
}

const authLoginProfiles = <AuthLoginProfile>[
  AuthLoginProfile(label: 'Nathik', userId: '1'),
  AuthLoginProfile(label: 'Yareni', userId: '2'),
];
