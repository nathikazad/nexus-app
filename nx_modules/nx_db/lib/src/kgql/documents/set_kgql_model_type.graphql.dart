/// GraphQL document for `set_kgql_model_types`.
const String setKgqlModelTypesMutation = '''
mutation SetKgqlModelTypes(\$input: SetKgqlModelTypesInput!) {
  setKgqlModelTypes(input: \$input) {
    json
  }
}
''';
