/// Loads all root model types (no filter).
const String getAllModelTypesQuery = '''
query GetAllModelTypes(\$domainId: Int!) {
  getKgqlModelType(input: {
    model_types: []
    struct: {
      id: true
      name: true
      type_kind: true
      description: true
      parent: true
      children: true
    }
  }, domainId: \$domainId)
}
''';
