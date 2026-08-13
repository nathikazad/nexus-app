import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_db/auth.dart' show User;
import 'package:nx_db/kgql.dart' show fetchKgqlModelById;

import '../../domain/person/person.dart';
import '../../domain/person/person_repository.dart';
import 'person_mapper.dart';

const _currentUserQuery = r'''
query CurrentUser($id: Int!) {
  allUsers(condition: { id: $id }, first: 1) {
    nodes {
      id
      name
      personModelId
      preferences
    }
  }
}
''';

const _updateUserPreferencesMutation = r'''
mutation UpdateUserPreferences($id: Int!, $preferences: JSON) {
  updateUserById(input: {
    id: $id,
    userPatch: { preferences: $preferences }
  }) {
    user {
      id
      preferences
    }
  }
}
''';

const _personStruct = {
  'id': true,
  'name': true,
  'description': true,
};

/// KGQL [Person] fetch with account preferences stored on `users.preferences`.
class KgqlPersonRepository implements PersonRepository {
  KgqlPersonRepository({
    required GraphQLClient client,
    required Future<User> Function() loadAuthenticatedUser,
  })  : _client = client,
        _loadAuthenticatedUser = loadAuthenticatedUser;

  final GraphQLClient _client;
  final Future<User> Function() _loadAuthenticatedUser;

  @override
  Future<Person?> getMain() async {
    final userRow = await _fetchCurrentUserRow();
    final personModelId = _asInt(userRow['personModelId']);
    if (personModelId == null) return null;

    final model = await fetchKgqlModelById(
      _client,
      modelTypeName: 'Person',
      id: personModelId,
      struct: _personStruct,
    );
    if (model == null) return null;
    return personFromModel(
      model,
      preference: _asStringKeyedMap(userRow['preferences']),
    );
  }

  @override
  Future<Person> updatePreference(
    Person person,
    Map<String, dynamic> preference,
  ) async {
    final userId = await _currentUserId();
    final result = await _client.mutate(
      MutationOptions(
        document: gql(_updateUserPreferencesMutation),
        variables: {
          'id': userId,
          'preferences': preference,
        },
      ),
    );
    if (result.hasException) {
      throw result.exception!;
    }
    return person.copyWith(preference: Map<String, dynamic>.from(preference));
  }

  Future<Map<String, dynamic>> _fetchCurrentUserRow() async {
    final userId = await _currentUserId();
    final result = await _client.query(
      QueryOptions(
        document: gql(_currentUserQuery),
        variables: {'id': userId},
        fetchPolicy: FetchPolicy.networkOnly,
      ),
    );
    if (result.hasException) {
      throw result.exception!;
    }

    final users = result.data?['allUsers'];
    final nodes = users is Map ? users['nodes'] : null;
    if (nodes is List && nodes.isNotEmpty) {
      final row = nodes.first;
      if (row is Map<String, dynamic>) return row;
      if (row is Map) return Map<String, dynamic>.from(row);
    }
    throw StateError('Current user row was not found.');
  }

  Future<int> _currentUserId() async {
    final user = await _loadAuthenticatedUser();
    final id = int.tryParse(user.userId);
    if (id == null) {
      throw StateError('Authenticated user id is not numeric: ${user.userId}');
    }
    return id;
  }
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

Map<String, dynamic> _asStringKeyedMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return Map<String, dynamic>.from(value);
  }
  if (value is Map) {
    return Map<String, dynamic>.from(
      value.map((key, child) => MapEntry(key.toString(), child)),
    );
  }
  return <String, dynamic>{};
}
