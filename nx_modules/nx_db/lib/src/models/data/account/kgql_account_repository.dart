import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_auth/nx_auth.dart' show User;
import 'dart:convert';

import '../../domain/account/account.dart';
import '../../domain/account/account_repository.dart';

const _currentUserQuery = r'''
query CurrentUser($id: Int!) {
  allUsers(condition: { id: $id }, first: 1) {
    nodes {
      id
      name
      description
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

/// Account profile and preferences stored on users.
class KgqlAccountRepository implements AccountRepository {
  KgqlAccountRepository({
    required GraphQLClient client,
    required Future<User> Function() loadAuthenticatedUser,
  }) : _client = client,
       _loadAuthenticatedUser = loadAuthenticatedUser;

  final GraphQLClient _client;
  final Future<User> Function() _loadAuthenticatedUser;

  @override
  Future<AccountProfile?> getCurrent() async {
    final userRow = await _fetchCurrentUserRow();
    dynamic preferences = userRow['preferences'];
    if (preferences is String) preferences = jsonDecode(preferences);
    return AccountProfile(
      id: _asInt(userRow['id'])!,
      name: userRow['name'] as String,
      description: userRow['description'] as String?,
      preferences: _asStringKeyedMap(preferences),
    );
  }

  @override
  Future<AccountProfile> updatePreference(
    AccountProfile account,
    Map<String, dynamic> preference,
  ) async {
    final userId = await _currentUserId();
    final result = await _client.mutate(
      MutationOptions(
        document: gql(_updateUserPreferencesMutation),
        variables: {'id': userId, 'preferences': preference},
      ),
    );
    if (result.hasException) {
      throw result.exception!;
    }
    return account.copyWith(preferences: Map<String, dynamic>.from(preference));
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
