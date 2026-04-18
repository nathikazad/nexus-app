/// GraphQL document for `set_kgql_models`.
const String setKgqlModelsMutation = '''
mutation SetKgqlModels(\$input: SetKgqlModelsInput!) {
  setKgqlModels(input: \$input) {
    json
  }
}
''';
