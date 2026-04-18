import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/backend_presets.dart';
import '../core/client/graphql_client.dart';
import '../kgql/documents/add_message_to_transcript.graphql.dart';
import '../kgql/documents/get_current_transcript.graphql.dart';
import '../kgql/documents/transcript_message_subscription.graphql.dart';
import 'transcript.dart';

/// Parses `getCurrentTranscript` payload (string, `json` wrapper, or map) to [Transcript].
@visibleForTesting
Transcript? parseTranscriptFromGraphqlResponse(dynamic transcriptData) {
  if (transcriptData is String) {
    try {
      transcriptData = json.decode(transcriptData) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  if (transcriptData is Map<String, dynamic> && transcriptData.containsKey('json')) {
    transcriptData = transcriptData['json'];
    if (transcriptData is String) {
      transcriptData = json.decode(transcriptData) as Map<String, dynamic>;
    }
  }

  if (transcriptData == null || transcriptData is! Map<String, dynamic>) {
    return null;
  }

  return Transcript.fromJson(transcriptData);
}

/// Transcript operations (GraphQL query, mutation, subscription).
class TranscriptService {
  static Future<({GraphQLClient client, int userId})> _getClientAndUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final userIdStr = prefs.getString(PrefsKeys.userId);
    final endpoint = prefs.getString(PrefsKeys.endpoint);

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

      final transcriptData = result.data?['getCurrentTranscript'];
      final parsed = parseTranscriptFromGraphqlResponse(transcriptData);
      if (parsed == null) {
        print('⚠️ No transcript data returned');
      }
      return parsed;
    } catch (e, stackTrace) {
      print('❌ Error in TranscriptService.getTranscript: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  static Future<void> addMessage({
    required int transcriptId,
    required String sender,
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

  static Stream<TranscriptMessage> streamMessages(int transcriptId) async* {
    print('TranscriptService: Starting message stream for transcript $transcriptId');

    final bundle = await _getClientAndUserId();
    final client = bundle.client;

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
          continue;
        }

        final subscriptionData = result.data?['transcriptMessageAdded'];
        if (subscriptionData == null) {
          continue;
        }

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
