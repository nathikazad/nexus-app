/// GraphQL query to get current transcript.
const String getCurrentTranscriptQuery = '''
query GetCurrentTranscript(\$userIdParam: Int!) {
  getCurrentTranscript(userIdParam: \$userIdParam)
}
''';
