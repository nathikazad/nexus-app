import 'person.dart';

/// Persistence for the current user's linked Person row and account preferences.
abstract class PersonRepository {
  /// Current user's linked Person model, enriched with `users.preferences`.
  Future<Person?> getMain();

  /// Replaces `users.preferences` for the authenticated user.
  Future<Person> updatePreference(
    Person person,
    Map<String, dynamic> preference,
  );
}
