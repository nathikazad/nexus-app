/// GraphQL subscription for new transcript messages.
const String transcriptMessageAddedSubscription = '''
subscription SubscribeToTranscriptMessages(\$transcriptId: Int) {
  transcriptMessageAdded(transcriptId: \$transcriptId) {
    transcriptId
    delta
    timestamp
    sender
    message
  }
}
''';
