/// GraphQL document for `get_kgql_model_type`.
const String kgqlGetKgqlModelTypeQuery = '''
query GetKgqlModelType(\$input: JSON!, \$domainId: Int!) {
  getKgqlModelType(input: \$input, domainId: \$domainId)
}
''';
