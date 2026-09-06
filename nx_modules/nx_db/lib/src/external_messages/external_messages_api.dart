import 'package:graphql_flutter/graphql_flutter.dart';

const String _externalMessagesQuery = r'''
query ExternalMessages(
  $first: Int!
  $after: Cursor
  $condition: ExternalMessageCondition!
) {
  allExternalMessages(
    first: $first
    after: $after
    condition: $condition
    orderBy: [SEQUENCE_ASC, MESSAGE_TIME_ASC, ID_ASC]
  ) {
    nodes {
      id
      provider
      externalAccountId
      externalThreadId
      externalMessageId
      messageTime
      sequence
      rawPayload
      firstSeenAt
      lastSeenAt
      deletedAt
    }
    pageInfo { hasNextPage endCursor }
  }
}
''';

const String _syncConversationMutation = r'''
mutation SyncExternalConversation($conversation: JSON!, $domainId: Int) {
  syncExternalConversation(
    input: {conversationParam: $conversation, domainId: $domainId}
  ) { json }
}
''';

final class ExternalMessage {
  const ExternalMessage({
    required this.id,
    required this.provider,
    required this.externalAccountId,
    required this.externalThreadId,
    required this.externalMessageId,
    required this.rawPayload,
    this.messageTime,
    this.sequence,
  });

  final String id;
  final String provider;
  final String externalAccountId;
  final String externalThreadId;
  final String externalMessageId;
  final DateTime? messageTime;
  final int? sequence;
  final Map<String, dynamic> rawPayload;

  String get text =>
      (rawPayload['text'] ?? rawPayload['body'] ?? '').toString();
  bool get fromCurrentUser =>
      rawPayload['is_from_me'] == true || rawPayload['from_me'] == true;
  List<Map<String, dynamic>> get attachments {
    final value = rawPayload['attachments'];
    if (value is! List) return const [];
    return [
      for (final item in value)
        if (item is Map) Map<String, dynamic>.from(item),
    ];
  }

  factory ExternalMessage.fromJson(Map<String, dynamic> json) =>
      ExternalMessage(
        id: json['id'].toString(),
        provider: json['provider']?.toString() ?? '',
        externalAccountId: json['externalAccountId']?.toString() ?? '',
        externalThreadId: json['externalThreadId']?.toString() ?? '',
        externalMessageId: json['externalMessageId']?.toString() ?? '',
        messageTime: DateTime.tryParse(json['messageTime']?.toString() ?? ''),
        sequence: json['sequence'] as int?,
        rawPayload: json['rawPayload'] is Map
            ? Map<String, dynamic>.from(json['rawPayload'] as Map)
            : const <String, dynamic>{},
      );
}

final class ExternalMessagePage {
  const ExternalMessagePage({
    required this.messages,
    this.endCursor,
    required this.hasNextPage,
  });
  final List<ExternalMessage> messages;
  final String? endCursor;
  final bool hasNextPage;
}

Future<ExternalMessagePage> fetchExternalMessages(
  GraphQLClient client, {
  required String provider,
  required String externalAccountId,
  required String externalThreadId,
  int first = 100,
  String? after,
}) async {
  final result = await client.query(
    QueryOptions(
      document: gql(_externalMessagesQuery),
      fetchPolicy: FetchPolicy.networkOnly,
      variables: <String, dynamic>{
        'first': first,
        'after': after,
        'condition': <String, dynamic>{
          'provider': provider,
          'externalAccountId': externalAccountId,
          'externalThreadId': externalThreadId,
        },
      },
    ),
  );
  if (result.hasException) throw result.exception!;
  final connection = result.data?['allExternalMessages'];
  if (connection is! Map) throw StateError('Invalid external message response');
  final nodes = connection['nodes'];
  final pageInfo = connection['pageInfo'];
  return ExternalMessagePage(
    messages: [
      if (nodes is List)
        for (final node in nodes)
          if (node is Map)
            ExternalMessage.fromJson(Map<String, dynamic>.from(node)),
    ],
    endCursor: pageInfo is Map ? pageInfo['endCursor'] as String? : null,
    hasNextPage: pageInfo is Map && pageInfo['hasNextPage'] == true,
  );
}

Future<Map<String, dynamic>> syncExternalConversation(
  GraphQLClient client, {
  required Map<String, dynamic> conversation,
  int? domainId,
}) async {
  final result = await client.mutate(
    MutationOptions(
      document: gql(_syncConversationMutation),
      variables: <String, dynamic>{
        'conversation': conversation,
        if (domainId != null) 'domainId': domainId,
      },
    ),
  );
  if (result.hasException) throw result.exception!;
  final payload = result.data?['syncExternalConversation'];
  final json = payload is Map ? payload['json'] : null;
  if (json is! Map) throw StateError('Invalid conversation sync response');
  return Map<String, dynamic>.from(json);
}
