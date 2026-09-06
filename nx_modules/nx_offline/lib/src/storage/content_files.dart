import 'dart:convert';

import 'content_files_stub.dart'
    if (dart.library.io) 'content_files_native.dart'
    as platform;

/// Body storage has no resident content cache. Callers own active documents.
abstract interface class ContentFiles {
  factory ContentFiles.application(String account) =
      platform.ApplicationContentFiles;

  /// Returns a small, versioned JSON reference after bytes are finalized.
  Future<String> write(String collection, String item, String content);

  /// Accepts legacy inline JSON, allowing resumable, per-record migration.
  Future<String> read(String reference);

  /// Checks existence and byte length without opening or decoding the body.
  Future<bool> exists(String reference);
}

bool isContentReference(String value) => value.startsWith('{"nx_file":1,');

final class ContentReference {
  const ContentReference(this.path, this.hash, this.bytes);
  final String path;
  final String hash;
  final int bytes;

  String encode() =>
      jsonEncode({'nx_file': 1, 'path': path, 'sha256': hash, 'bytes': bytes});

  factory ContentReference.decode(String value) {
    final json = jsonDecode(value) as Map;
    if (json['nx_file'] != 1 ||
        json['path'] is! String ||
        json['sha256'] is! String ||
        json['bytes'] is! int) {
      throw const FormatException('Invalid content file reference');
    }
    return ContentReference(
      json['path'] as String,
      json['sha256'] as String,
      json['bytes'] as int,
    );
  }
}
