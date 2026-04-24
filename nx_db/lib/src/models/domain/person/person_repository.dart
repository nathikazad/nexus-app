import 'person.dart';

/// Persistence for the current user’s Person row and `preference` JSON.
abstract class PersonRepository {
  /// First Person model for the current user (RLS).
  Future<Person?> getMain();

  /// Replaces the root `preference` map (use when merging manually).
  Future<Person> updatePreference(
    Person person,
    Map<String, dynamic> preference,
  );
}
