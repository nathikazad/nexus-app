import 'dart:convert';

import 'binary_files_stub.dart'
    if (dart.library.io) 'binary_files_native.dart'
    as platform;

abstract interface class BinaryContentFiles {
  factory BinaryContentFiles.application(String account) =
      platform.ApplicationBinaryContentFiles;

  Future<BinaryContentReference> write(
    String collection,
    String item,
    String extension,
    Stream<List<int>> bytes,
  );
  Future<bool> verify(BinaryContentReference reference);
  Future<String> localPath(BinaryContentReference reference);
}

/// Directory-backed implementation exposed for deterministic tests and for
/// applications that already own a persistent storage directory.
abstract interface class DirectoryBinaryContentFiles
    implements BinaryContentFiles {
  factory DirectoryBinaryContentFiles(String rootPath) =
      platform.DirectoryBinaryContentFilesImpl;
}

class BinaryContentReference {
  const BinaryContentReference({
    required this.path,
    required this.hash,
    required this.bytes,
  });
  final String path;
  final String hash;
  final int bytes;

  String encode() => jsonEncode({
    'nx_binary': 1,
    'path': path,
    'sha256': hash,
    'bytes': bytes,
  });

  factory BinaryContentReference.decode(String value) {
    final json = jsonDecode(value) as Map;
    if (json['nx_binary'] != 1 ||
        json['path'] is! String ||
        json['sha256'] is! String ||
        json['bytes'] is! int) {
      throw const FormatException('Invalid binary file reference');
    }
    return BinaryContentReference(
      path: json['path'] as String,
      hash: json['sha256'] as String,
      bytes: json['bytes'] as int,
    );
  }
}
