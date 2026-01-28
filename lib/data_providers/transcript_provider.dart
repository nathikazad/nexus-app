import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'dart:convert';
import 'package:nexus_voice_assistant/db.dart';
import 'package:nexus_voice_assistant/models/transcript_message.dart';
import 'package:nexus_voice_assistant/auth.dart';

// GraphQL query to get current transcript
const String getCurrentTranscriptQuery = '''
query GetCurrentTranscript(\$userIdParam: Int!) {
  getCurrentTranscript(userIdParam: \$userIdParam)
}
''';

// GraphQL mutation to add a message to transcript
const String addMessageToTranscriptMutation = '''
mutation AddMessageToTranscript(\$input: AddMessageToTranscriptInput!) {
  addMessageToTranscript(input: \$input) {
    json
  }
}
''';

// GraphQL subscription for new messages
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

/// Provider for getting the current transcript
final currentTranscriptProvider = FutureProvider<Transcript?>((ref) async {
  final client = ref.watch(graphqlClientProvider);
  final userIdStr = ref.watch(userIdProvider);
  
  if (userIdStr == null) {
    return null;
  }
  
  final userId = int.tryParse(userIdStr);
  if (userId == null) {
    print('⚠️ Invalid user ID: $userIdStr');
    return null;
  }
  
  final queryOptions = QueryOptions(
    document: gql(getCurrentTranscriptQuery),
    variables: {
      'userIdParam': userId,
    },
    fetchPolicy: FetchPolicy.networkOnly,
  );
  
  try {
    final result = await client.query(queryOptions);
    
    if (result.hasException) {
      print('❌ GraphQL Error in getCurrentTranscript:');
      print('Exception: ${result.exception}');
      if (result.exception?.graphqlErrors != null) {
        for (var error in result.exception!.graphqlErrors) {
          print('  - ${error.message}');
        }
      }
      throw result.exception!;
    }
    
    // Extract transcript data
    var transcriptData = result.data?['getCurrentTranscript'];
    
    // Parse JSON string if needed
    if (transcriptData is String) {
      try {
        transcriptData = json.decode(transcriptData) as Map<String, dynamic>;
      } catch (e) {
        print('⚠️ Failed to parse transcript JSON string: $e');
        return null;
      }
    }
    
    // If it's wrapped in a json field, extract it
    if (transcriptData is Map<String, dynamic> && transcriptData.containsKey('json')) {
      transcriptData = transcriptData['json'];
      if (transcriptData is String) {
        transcriptData = json.decode(transcriptData) as Map<String, dynamic>;
      }
    }
    
    if (transcriptData == null || transcriptData is! Map<String, dynamic>) {
      print('⚠️ No transcript data returned');
      return null;
    }
    
    return Transcript.fromJson(transcriptData);
  } catch (e, stackTrace) {
    print('❌ Error in currentTranscriptProvider: $e');
    print('Stack trace: $stackTrace');
    rethrow;
  }
});

/// Parameters for sending a message
class SendMessageParams {
  final int transcriptId;
  final String sender; // "Human" or "Agent"
  final String message;
  final int userId;
  
  SendMessageParams({
    required this.transcriptId,
    required this.sender,
    required this.message,
    required this.userId,
  });
}

/// Provider for sending a message to transcript
final sendMessageProvider = FutureProvider.family<void, SendMessageParams>((ref, params) async {
  final client = ref.watch(graphqlClientProvider);
  
  final mutationOptions = MutationOptions(
    document: gql(addMessageToTranscriptMutation),
    variables: {
      'input': {
        'transcriptIdParam': params.transcriptId,
        'senderParam': params.sender,
        'messageParam': params.message,
        'userIdParam': params.userId,
      },
    },
  );
  
  try {
    final result = await client.mutate(mutationOptions);
    
    if (result.hasException) {
      print('❌ GraphQL Error in addMessageToTranscript:');
      print('Exception: ${result.exception}');
      if (result.exception?.graphqlErrors != null) {
        for (var error in result.exception!.graphqlErrors) {
          print('  - ${error.message}');
        }
      }
      throw result.exception!;
    }
    
    // Invalidate currentTranscriptProvider to refresh
    ref.invalidate(currentTranscriptProvider);
  } catch (e, stackTrace) {
    print('❌ Error in sendMessageProvider: $e');
    print('Stack trace: $stackTrace');
    rethrow;
  }
});

/// Provider for subscribing to new transcript messages
final transcriptMessagesStreamProvider = StreamProvider.family<TranscriptMessage, int>((ref, transcriptId) async* {
  final client = ref.watch(graphqlClientProvider);
  
  final subscriptionOptions = SubscriptionOptions(
    document: gql(transcriptMessageAddedSubscription),
    variables: {
      'transcriptId': transcriptId,
    },
  );
  
  try {
    await for (final result in client.subscribe(subscriptionOptions)) {
      if (result.hasException) {
        print('❌ GraphQL Subscription Error:');
        print('Exception: ${result.exception}');
        if (result.exception?.graphqlErrors != null) {
          for (var error in result.exception!.graphqlErrors) {
            print('  - ${error.message}');
          }
        }
        continue; // Skip this error and continue listening
      }
      
      // Extract message data from subscription
      final subscriptionData = result.data?['transcriptMessageAdded'];
      if (subscriptionData == null) {
        continue;
      }
      
      // Parse the message
      if (subscriptionData is Map<String, dynamic>) {
        try {
          final message = TranscriptMessage.fromJson(subscriptionData);
          yield message;
        } catch (e) {
          print('⚠️ Failed to parse subscription message: $e');
          print('Data: $subscriptionData');
        }
      }
    }
  } catch (e, stackTrace) {
    print('❌ Error in transcriptMessagesStreamProvider: $e');
    print('Stack trace: $stackTrace');
    rethrow;
  }
});
