import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import 'content_files.dart';

/// App-private persistent storage. Account names are hashed, never raw paths.
class ApplicationContentFiles implements ContentFiles {
  ApplicationContentFiles(this.account);
  final String account;
  late final Future<DirectoryContentFiles> _files =
      getApplicationSupportDirectory().then(
        (directory) => DirectoryContentFiles(
          Directory(
            '${directory.path}/offline/${sha256.convert(utf8.encode(account))}',
          ),
        ),
      );

  @override
  Future<String> write(String collection, String item, String content) async =>
      (await _files).write(collection, item, content);
  @override
  Future<String> read(String reference) async => (await _files).read(reference);
  @override
  Future<bool> exists(String reference) async =>
      (await _files).exists(reference);
}

/// Files are immutable and finalized before a database reference is published.
/// Old files are retained: queues, snapshots and conflicts can refer to them.
class DirectoryContentFiles implements ContentFiles {
  DirectoryContentFiles(this.directory);
  final Directory directory;
  int reads = 0;
  int writes = 0;
  int bytesRead = 0;

  @override
  Future<bool> exists(String reference) async {
    if (!isContentReference(reference)) return true;
    final ref = ContentReference.decode(reference);
    await _checkPath(ref.path);
    final stat = await File('${directory.path}/${ref.path}').stat();
    return stat.type == FileSystemEntityType.file && stat.size == ref.bytes;
  }

  String _component(String value) {
    if (value.length > 80 || !RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(value)) {
      return 'id_${sha256.convert(utf8.encode(value))}';
    }
    return value;
  }

  Future<void> _checkPath(String relative) async {
    if (!RegExp(
      r'^[a-zA-Z0-9_-]+/[a-zA-Z0-9_-]+/[a-f0-9]{64}\.json$',
    ).hasMatch(relative)) {
      throw const FormatException('Unsafe content path');
    }
    var path = directory.path;
    if (await FileSystemEntity.type(path, followLinks: false) ==
        FileSystemEntityType.link) {
      throw const FileSystemException('Content root is a symbolic link');
    }
    for (final component in relative.split('/')) {
      path = '$path/$component';
      if (await FileSystemEntity.type(path, followLinks: false) ==
          FileSystemEntityType.link) {
        throw const FileSystemException(
          'Content path contains a symbolic link',
        );
      }
    }
  }

  @override
  Future<String> write(String collection, String item, String content) async {
    final (bytes, hash) = content.length > 65536
        ? await Isolate.run(() => _encode(content))
        : _encode(content);
    final path = '${_component(collection)}/${_component(item)}/$hash.json';
    await _checkPath(path);
    final destination = File('${directory.path}/$path');
    await destination.parent.create(recursive: true);
    if (!await destination.exists()) {
      final staging = await destination.parent.createTemp('.staging-');
      final temporary = File('${staging.path}/content');
      try {
        await temporary.writeAsBytes(bytes, flush: true);
        await temporary.rename(destination.path);
        writes++;
      } finally {
        if (await temporary.exists()) await temporary.delete();
        await staging.delete();
      }
    } else {
      final existing = await destination.readAsBytes();
      reads++;
      bytesRead += existing.length;
      final valid = existing.length > 65536
          ? await Isolate.run(() => sha256.convert(existing).toString() == hash)
          : sha256.convert(existing).toString() == hash;
      if (!valid) {
        throw FileSystemException(
          'Existing content is corrupt',
          destination.path,
        );
      }
    }
    return ContentReference(path, hash, bytes.length).encode();
  }

  @override
  Future<String> read(String reference) async {
    if (!isContentReference(reference)) return reference;
    final ref = ContentReference.decode(reference);
    await _checkPath(ref.path);
    final bytes = await File('${directory.path}/${ref.path}').readAsBytes();
    reads++;
    bytesRead += bytes.length;
    if (bytes.length != ref.bytes) {
      throw const FormatException('Content size mismatch');
    }
    return bytes.length > 65536
        ? await Isolate.run(() => _decode(bytes, ref.hash))
        : _decode(bytes, ref.hash);
  }
}

(List<int>, String) _encode(String content) {
  final bytes = utf8.encode(content);
  return (bytes, sha256.convert(bytes).toString());
}

String _decode(List<int> bytes, String expectedHash) {
  if (sha256.convert(bytes).toString() != expectedHash) {
    throw const FormatException('Content checksum mismatch');
  }
  return utf8.decode(bytes);
}
