/// The authenticated account's profile and settings from public.users.
class AccountProfile {
  const AccountProfile({
    required this.id,
    required this.name,
    this.description,
    this.preferences = const <String, dynamic>{},
  });
  final int id;
  final String name;
  final String? description;
  final Map<String, dynamic> preferences;
  AccountProfile copyWith({
    int? id,
    String? name,
    String? description,
    Map<String, dynamic>? preferences,
  }) => AccountProfile(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description ?? this.description,
    preferences: preferences ?? this.preferences,
  );
}
