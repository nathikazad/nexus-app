/// GraphQL mutation to add a message to transcript.
const String addMessageToTranscriptMutation = '''
mutation AddMessageToTranscript(\$input: AddMessageToTranscriptInput!) {
  addMessageToTranscript(input: \$input) {
    json
  }
}
''';
