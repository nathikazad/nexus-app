import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:nx_notes/data/document/document_image_file_reader_stub.dart'
    if (dart.library.io) 'package:nx_notes/data/document/document_image_file_reader_io.dart';

class DocumentImageAssetService {
  DocumentImageAssetService({
    required String baseUrl,
    required String userId,
    required http.Client client,
  }) : _baseUri = Uri.parse(_trimTrailingSlash(baseUrl)),
       _userId = userId,
       _client = client;

  final Uri _baseUri;
  final String _userId;
  final http.Client _client;

  String get imageBaseUrl => _baseUri.toString();

  Future<String> storeImageSource({
    required int documentId,
    required String source,
  }) async {
    if (isNetworkImageUrl(source)) {
      _debugDocumentImage(
        'insert external image document_id=$documentId source=$source',
      );
      return source;
    }
    final payload = await _imagePayloadFromSource(source);
    final uploadUri = _baseUri.resolve('/notes/assets/images');
    _debugDocumentImage(
      'upload start document_id=$documentId uri=$uploadUri '
      'filename=${payload.filename} bytes=${payload.bytes.length}',
    );
    final request = http.MultipartRequest('POST', uploadUri)
      ..headers['X-User-Id'] = _userId
      ..fields['document_id'] = '$documentId'
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          payload.bytes,
          filename: payload.filename,
        ),
      );
    final response = await http.Response.fromStream(
      await _client.send(request),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Image upload failed (${response.statusCode})');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['url'] is! String) {
      throw StateError('Image upload returned an invalid response');
    }
    final storedUrl = _storedDocumentImageUrl(decoded['url'] as String);
    _debugDocumentImage(
      'upload complete document_id=$documentId status=${response.statusCode} '
      'stored_url=$storedUrl resolved_url=${resolveImageUrl(storedUrl)}',
    );
    return storedUrl;
  }

  Future<bool> deleteImageUrl(String url) async {
    final ref = DocumentImageAssetRef.tryParseRelative(url);
    if (ref == null) {
      _debugDocumentImage('skip delete for external image url=$url');
      return false;
    }
    final deleteUri = _absoluteAssetUri(ref.relativeUrl);
    _debugDocumentImage('delete start uri=$deleteUri');
    final response = await _client.delete(deleteUri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Image delete failed (${response.statusCode})');
    }
    _debugDocumentImage('delete complete status=${response.statusCode}');
    return true;
  }

  String resolveImageUrl(String storedUrl) {
    final ref = DocumentImageAssetRef.tryParseRelative(storedUrl);
    if (ref == null) {
      return storedUrl;
    }
    return _absoluteAssetUri(ref.relativeUrl).toString();
  }

  String _storedDocumentImageUrl(String raw) {
    final ref = DocumentImageAssetRef.tryParse(raw);
    if (ref == null) {
      throw StateError('Image upload returned an invalid image URL');
    }
    return ref.relativeUrl;
  }

  Uri _absoluteAssetUri(String raw) {
    final uri = Uri.parse(raw);
    if (uri.hasScheme) {
      return uri;
    }
    return _baseUri.resolve(raw);
  }
}

class DocumentImageAssetRef {
  const DocumentImageAssetRef({
    required this.userId,
    required this.documentId,
    required this.name,
  });

  final int userId;
  final int documentId;
  final String name;

  String get relativeUrl {
    return Uri(
      path: '/notes/assets/images/file',
      queryParameters: <String, String>{
        'user_id': '$userId',
        'document_id': '$documentId',
        'name': name,
      },
    ).toString();
  }

  static DocumentImageAssetRef? tryParse(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.path != '/notes/assets/images/file') {
      return null;
    }
    final userId = int.tryParse(uri.queryParameters['user_id'] ?? '');
    final documentId = int.tryParse(uri.queryParameters['document_id'] ?? '');
    final name = uri.queryParameters['name'];
    if (userId == null ||
        userId <= 0 ||
        documentId == null ||
        documentId <= 0 ||
        name == null ||
        !_isSafeImageName(name)) {
      return null;
    }
    return DocumentImageAssetRef(
      userId: userId,
      documentId: documentId,
      name: name,
    );
  }

  static DocumentImageAssetRef? tryParseRelative(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.hasScheme || uri.host.isNotEmpty) {
      return null;
    }
    return tryParse(raw);
  }
}

bool isNetworkImageUrl(String source) {
  final uri = Uri.tryParse(source);
  return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
}

void _debugDocumentImage(String message) {
  debugPrint('[nx_notes image] $message');
}

Future<_ImagePayload> _imagePayloadFromSource(String source) async {
  final dataUrlPayload = _payloadFromDataUrl(source);
  if (dataUrlPayload != null) {
    return dataUrlPayload;
  }

  final rawBase64Payload = _payloadFromRawBase64(source);
  if (rawBase64Payload != null) {
    return rawBase64Payload;
  }

  final bytes = Uint8List.fromList(await readNxDocumentImageFileBytes(source));
  final ext = _extensionFromBytes(bytes) ?? _extensionFromPath(source);
  if (ext == null) {
    throw StateError('Only JPG and PNG images are supported');
  }
  return _ImagePayload(bytes: bytes, filename: _generatedFilename(ext));
}

_ImagePayload? _payloadFromDataUrl(String source) {
  final match = RegExp(
    r'^data:image/(png|jpe?g);base64,(.+)$',
  ).firstMatch(source);
  if (match == null) {
    return null;
  }
  final subtype = match.group(1)!.toLowerCase();
  final bytes = base64Decode(match.group(2)!);
  return _ImagePayload(
    bytes: bytes,
    filename: _generatedFilename(subtype == 'png' ? '.png' : '.jpg'),
  );
}

_ImagePayload? _payloadFromRawBase64(String source) {
  try {
    final bytes = base64Decode(source);
    final ext = _extensionFromBytes(bytes);
    if (ext == null) {
      return null;
    }
    return _ImagePayload(bytes: bytes, filename: _generatedFilename(ext));
  } on FormatException {
    return null;
  }
}

String? _extensionFromBytes(Uint8List bytes) {
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4e &&
      bytes[3] == 0x47) {
    return '.png';
  }
  if (bytes.length >= 2 && bytes[0] == 0xff && bytes[1] == 0xd8) {
    return '.jpg';
  }
  return null;
}

String? _extensionFromPath(String path) {
  final lower = path.toLowerCase();
  if (lower.endsWith('.png')) return '.png';
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return '.jpg';
  return null;
}

String _generatedFilename(String extension) {
  return 'document-image-${DateTime.now().microsecondsSinceEpoch}$extension';
}

bool _isSafeImageName(String name) {
  if (name.contains('/') || name.contains('\\') || name.contains('..')) {
    return false;
  }
  final lower = name.toLowerCase();
  if (!lower.endsWith('.png') &&
      !lower.endsWith('.jpg') &&
      !lower.endsWith('.jpeg')) {
    return false;
  }
  return RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(name);
}

String _trimTrailingSlash(String value) {
  return value.endsWith('/') ? value.substring(0, value.length - 1) : value;
}

class _ImagePayload {
  const _ImagePayload({required this.bytes, required this.filename});

  final Uint8List bytes;
  final String filename;
}
