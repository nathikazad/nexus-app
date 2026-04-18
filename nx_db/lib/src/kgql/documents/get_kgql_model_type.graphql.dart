/// GraphQL document for `get_kgql_model_type`.
const String kgqlGetKgqlModelTypeQuery = '''
query GetKgqlModelType(\$input: JSON!) {
  getKgqlModelType(input: \$input)
}
''';
