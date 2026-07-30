const String setKgqlModelIfNewerMutation = r'''
mutation SetKgqlModelIfNewer($input: SetKgqlModelIfNewerInput!) {
  setKgqlModelIfNewer(input: $input) {
    json
  }
}
''';
