import 'package:graphql_flutter/graphql_flutter.dart';

import '../../../kgql/documents/add_message_to_transcript.graphql.dart';
import '../../../kgql/documents/get_current_transcript.graphql.dart';
import '../../../kgql/documents/transcript_message_subscription.graphql.dart';
import '../../domain/transcript/transcript.dart';
import '../../domain/transcript/transcript_repository.dart';
import 'transcript_mapper.dart';

/// KGQL implementation of [TranscriptRepository] over an injected [GraphQLClient].
class KgqlTranscriptRepository implements TranscriptRepository {
  KgqlTranscriptRepository({
    required GraphQLClient client,
    required int Function() currentUserId,
  })  : _client = client,
        _currentUserId = currentUserId;

  final GraphQLClient _client;
  final int Function() _currentUserId;

  @override
  Future<Transcript?> getCurrent() async {
    final userId = _currentUserId();
    final queryOptions = QueryOptions(
      document: gql(getCurrentTranscriptQuery),
      variables: {
        'userIdParam': userId,
      },
      fetchPolicy: FetchPolicy.networkOnly,
    );
    final result = await _client.query(queryOptions);
    if (result.hasException) {
      throw result.exception!;
    }
    final transcriptData = result.data?['getCurrentTranscript'];
    return parseTranscriptFromGraphqlResponse(transcriptData);
  }

  @override
  Future<void> addMessage({
    required int transcriptId,
    required String sender,
    required String message,
  }) async {
    final userId = _currentUserId();
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
    final result = await _client.mutate(mutationOptions);
    if (result.hasException) {
      throw result.exception!;
    }
  }

  @override
  Stream<TranscriptMessage> watchMessages(int transcriptId) async* {
    final subscriptionOptions = SubscriptionOptions(
      document: gql(transcriptMessageAddedSubscription),
      variables: {
        'transcriptId': transcriptId,
      },
    );
    try {
      await for (final result in _client.subscribe(subscriptionOptions)) {
        if (result.hasException) {
          continue;
        }
        final subscriptionData = result.data?['transcriptMessageAdded'];
        if (subscriptionData == null) {
          continue;
        }
        if (subscriptionData is Map<String, dynamic>) {
          try {
            yield TranscriptMessage.fromJson(subscriptionData);
          } catch (_) {
            // Malformed message — skip
          }
        }
      }
    } catch (e) {
      rethrow;
    }
  }
}
