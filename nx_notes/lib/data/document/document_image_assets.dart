import 'dart:convert';
import 'dart:typed_data';

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

  Future<String> storeImageSource({
    required int documentId,
    required String source,
  }) async {
    if (isNetworkImageUrl(source)) {
      return source;
    }
    final payload = await _imagePayloadFromSource(source);
    final request =
        http.MultipartRequest('POST', _baseUri.resolve('/notes/assets/images'))
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
    return _absoluteAssetUrl(decoded['url'] as String);
  }

  Future<bool> deleteImageUrl(String url) async {
    final ref = DocumentImageAssetRef.tryParse(url);
    if (ref == null) {
      return false;
    }
    final response = await _client.delete(_absoluteAssetUri(ref.relativeUrl));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Image delete failed (${response.statusCode})');
    }
    return true;
  }

  String _absoluteAssetUrl(String raw) => _absoluteAssetUri(raw).toString();

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
}

bool isNetworkImageUrl(String source) {
  final uri = Uri.tryParse(source);
  return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
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
