import 'dart:convert';

import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_db/external_messages.dart';
import 'package:nx_people/domain/person/person.dart';

class ConversationRepository {
  ConversationRepository({required GraphQLClient client}) : _client = client;

  final GraphQLClient _client;

  Future<List<ExternalMessage>> loadAll(PersonConversation conversation) async {
    final messages = <ExternalMessage>[];
    String? cursor;
    do {
      final page = await fetchExternalMessages(
        _client,
        provider: conversation.provider,
        externalAccountId: conversation.externalAccountId,
        externalThreadId: conversation.externalThreadId,
        after: cursor,
      );
      messages.addAll(page.messages);
      cursor = page.hasNextPage ? page.endCursor : null;
    } while (cursor != null);
    return messages;
  }

  Future<void> setResponsePending({
    required int personId,
    required PersonConversation conversation,
    required bool pending,
  }) async {
    await syncExternalConversation(
      _client,
      conversation: <String, dynamic>{
        'person_id': personId,
        'provider': conversation.provider,
        'external_account_id': conversation.externalAccountId,
        'external_thread_id': conversation.externalThreadId,
        'name': conversation.name,
        'summary': conversation.summary,
        'last_message_at': conversation.lastMessageAt
            ?.toUtc()
            .toIso8601String(),
        'response_pending': pending,
        'messages': const <dynamic>[],
      },
    );
  }

  Future<void> addAttachments({
    required int personId,
    required PersonConversation conversation,
    required List<Map<String, dynamic>> attachments,
  }) async {
    final stamp = DateTime.now().toUtc().microsecondsSinceEpoch;
    await syncExternalConversation(
      _client,
      conversation: <String, dynamic>{
        'person_id': personId,
        'provider': conversation.provider,
        'external_account_id': conversation.externalAccountId,
        'external_thread_id': conversation.externalThreadId,
        'name': conversation.name,
        'summary': conversation.summary,
        'last_message_at': conversation.lastMessageAt
            ?.toUtc()
            .toIso8601String(),
        'response_pending': conversation.responsePending,
        'messages': <Map<String, dynamic>>[
          for (var index = 0; index < attachments.length; index++)
            <String, dynamic>{
              'provider': conversation.provider,
              'external_account_id': conversation.externalAccountId,
              'external_thread_id': conversation.externalThreadId,
              'external_message_id': 'local-attachment-$stamp-$index',
              'raw_payload': <String, dynamic>{
                'body': '',
                'is_from_me': true,
                'attachments': <Map<String, dynamic>>[attachments[index]],
                'id_source': 'nx_people_attachment_upload',
              },
            },
        ],
      },
    );
  }

  Future<Map<String, dynamic>> importJson({
    required int personId,
    required List<int> bytes,
  }) async {
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map) {
      throw const FormatException('Import must be a JSON object.');
    }
    final payload = Map<String, dynamic>.from(decoded);
    payload['person_id'] = personId;
    _normalizeImport(payload);
    return syncExternalConversation(_client, conversation: payload);
  }

  void _normalizeImport(Map<String, dynamic> payload) {
    payload['provider'] = (payload['provider'] ?? payload['platform'] ?? '')
        .toString()
        .toLowerCase();
    payload['external_account_id'] =
        (payload['external_account_id'] ?? payload['account_id'] ?? 'default')
            .toString();
    payload['external_thread_id'] =
        (payload['external_thread_id'] ??
                payload['thread_id'] ??
                payload['identifier'] ??
                payload['name'] ??
                '')
            .toString();
    payload['name'] ??= payload['person_name'];
    payload['summary'] ??=
        payload['conversation_summary'] ?? payload['description'] ?? '';
    payload['response_pending'] ??= payload['pending_response'] ?? false;
    final messages = payload['messages'];
    if (messages is List) {
      payload['messages'] = [
        for (var index = 0; index < messages.length; index++)
          if (messages[index] is Map)
            _normalizeMessage(
              Map<String, dynamic>.from(messages[index] as Map),
              payload,
              index,
            ),
      ];
    } else {
      payload['messages'] = const <dynamic>[];
    }
  }

  Map<String, dynamic> _normalizeMessage(
    Map<String, dynamic> message,
    Map<String, dynamic> conversation,
    int index,
  ) {
    final raw = message['raw_payload'] is Map
        ? Map<String, dynamic>.from(message['raw_payload'] as Map)
        : Map<String, dynamic>.from(message);
    final sentAt =
        message['message_time'] ??
        message['sent_at'] ??
        message['timestamp'] ??
        raw['sent_at'];
    final externalId =
        message['external_message_id'] ??
        message['message_id'] ??
        raw['message_id'] ??
        '${conversation['external_thread_id']}:$index';
    return <String, dynamic>{
      'provider': conversation['provider'],
      'external_account_id': conversation['external_account_id'],
      'external_thread_id': conversation['external_thread_id'],
      'external_message_id': externalId.toString(),
      if (sentAt != null) 'message_time': sentAt.toString(),
      'sequence': message['sequence'] ?? index + 1,
      'raw_payload': raw,
    };
  }
}
