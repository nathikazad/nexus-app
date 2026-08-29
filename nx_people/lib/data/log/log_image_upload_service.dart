import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:nx_db/auth.dart';

class LogImageUploadService {
  LogImageUploadService({required String baseUrl, required http.Client client})
    : _baseUrl = normalizeHttpEndpoint(baseUrl).replaceFirst(RegExp(r'/$'), ''),
      _client = client;

  final String _baseUrl;
  final http.Client _client;

  Future<String> upload({
    required List<int> bytes,
    required String filename,
  }) async {
    final request =
        http.MultipartRequest('POST', Uri.parse('$_baseUrl/snapshots'))
          ..fields['timestamp'] = _timestamp12Digits(DateTime.now())
          ..fields['source'] = 'people_app'
          ..fields['timezone'] = _timezoneName()
          ..files.add(
            http.MultipartFile.fromBytes('file', bytes, filename: filename),
          );
    final response = await http.Response.fromStream(
      await _client.send(request),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Image upload failed (${response.statusCode}).');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['ok'] != true) {
      throw StateError('Image upload returned an invalid response.');
    }
    final imageUrl = decoded['image_url']?.toString().trim() ?? '';
    if (imageUrl.isNotEmpty) return imageUrl;
    final filenameResult = decoded['filename']?.toString().trim() ?? '';
    if (filenameResult.isEmpty) {
      throw StateError('Image upload did not return a filename.');
    }
    return Uri(
      path: '/images/file',
      queryParameters: <String, String>{'name': filenameResult},
    ).toString();
  }
}

String _timestamp12Digits(DateTime value) {
  String two(int part) => part.toString().padLeft(2, '0');
  return '${two(value.year % 100)}${two(value.month)}${two(value.day)}'
      '${two(value.hour)}${two(value.minute)}${two(value.second)}';
}

String _timezoneName() {
  final value = DateTime.now().timeZoneName.trim();
  return value.isEmpty ? 'UTC' : value;
}
