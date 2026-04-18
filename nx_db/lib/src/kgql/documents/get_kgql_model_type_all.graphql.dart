/// Loads all root model types (no filter).
const String getAllModelTypesQuery = '''
query GetAllModelTypes {
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
  })
}
''';
