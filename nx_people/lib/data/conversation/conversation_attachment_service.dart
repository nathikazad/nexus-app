import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:nx_db/auth.dart';

class ConversationAttachmentService {
  ConversationAttachmentService({
    required String baseUrl,
    required http.Client client,
  }) : _baseUrl = normalizeHttpEndpoint(
         baseUrl,
       ).replaceFirst(RegExp(r'/$'), ''),
       _client = client;

  final String _baseUrl;
  final http.Client _client;

  Future<Map<String, dynamic>> upload({
    required String provider,
    required String externalAccountId,
    required String externalThreadId,
    required String filename,
    required List<int> bytes,
  }) async {
    final request =
        http.MultipartRequest(
            'POST',
            Uri.parse('$_baseUrl/people/assets/attachments'),
          )
          ..fields['provider'] = provider
          ..fields['external_account_id'] = externalAccountId
          ..fields['external_thread_id'] = externalThreadId
          ..files.add(
            http.MultipartFile.fromBytes('file', bytes, filename: filename),
          );
    final response = await http.Response.fromStream(
      await _client.send(request),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Attachment upload failed (${response.statusCode}).');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['url'] == null) {
      throw StateError('Attachment upload returned an invalid response.');
    }
    return Map<String, dynamic>.from(decoded);
  }
}
