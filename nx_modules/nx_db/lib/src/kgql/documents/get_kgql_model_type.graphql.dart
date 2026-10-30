/// GraphQL document for `get_kgql_model_type`.
const String kgqlGetKgqlModelTypeQuery = '''
query GetKgqlModelType(\$input: JSON!) {
  getKgqlModelType(input: \$input)
}
''';

/// The schema editor also needs definition ownership; ordinary app reads do not.
const String kgqlGetModelTypeWithOwnersQuery = r'''
query GetKgqlModelTypeWithOwners($input: JSON!) {
  getKgqlModelType(input: $input)
  allRelationshipTypes(first: 10000) { nodes { id fromModelTypeId } }
}
''';
