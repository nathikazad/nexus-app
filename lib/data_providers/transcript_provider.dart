import 'package:graphql_flutter/graphql_flutter.dart';
import 'dart:async';
import 'dart:convert';
import 'package:nexus_voice_assistant/db.dart';
import 'package:nexus_voice_assistant/models/transcript_message.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

/// Class for managing transcript operations
class TranscriptService {
  static const String _userIdKey = 'auth_user_id';
  static const String _endpointKey = 'auth_endpoint';

  /// Get the GraphQL client and userId from SharedPreferences
  static Future<({GraphQLClient client, int userId})> _getClientAndUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final userIdStr = prefs.getString(_userIdKey);
    final endpoint = prefs.getString(_endpointKey);

    if (userIdStr == null || endpoint == null) {
      throw Exception('User not authenticated. Please log in first.');
    }

    final userId = int.tryParse(userIdStr);
    if (userId == null) {
      throw Exception('Invalid user ID: $userIdStr');
    }

    final client = createClient(endpoint, userIdStr);
    return (client: client, userId: userId);
  }

  /// Get the current transcript for the logged-in user
  static Future<Transcript?> getTranscript() async {
    print('TranscriptService: Fetching transcript');
    
    final (client: client, userId: userId) = await _getClientAndUserId();
    
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
      print('❌ Error in TranscriptService.getTranscript: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Add a message to the transcript
  static Future<void> addMessage({
    required int transcriptId,
    required String sender, // "Human" or "Agent"
    required String message,
  }) async {
    print('TranscriptService: Adding message to transcript');
    
    final (client: client, userId: userId) = await _getClientAndUserId();
    
    final mutationOptions = MutationOptions(
      document: gql(addMessageToTranscriptMutation),
      variables: {
        'input': {
          'transcriptIdParam': transcriptId,
          'senderParam': sender,
          'messageParam': message,
          'userIdParam': userId,
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
      
      print('✅ Message added successfully');
    } catch (e, stackTrace) {
      print('❌ Error in TranscriptService.addMessage: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Stream of new transcript messages for a given transcript ID
  static Stream<TranscriptMessage> streamMessages(int transcriptId) async* {
    print('TranscriptService: Starting message stream for transcript $transcriptId');
    
    final (client: client, userId: userId) = await _getClientAndUserId();
    
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
      print('❌ Error in TranscriptService.streamMessages: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }
}
