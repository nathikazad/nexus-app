/// GraphQL document for `get_kgql_models`.
const String kgqlGetKgqlModelsQuery = '''
query GetKgqlModels(\$filter: JSON!, \$struct: JSON!, \$domainId: Int!) {
  getKgqlModels(filter: \$filter, struct: \$struct, domainId: \$domainId)
}
''';
