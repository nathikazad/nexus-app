import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import 'binary_files.dart';

class ApplicationBinaryContentFiles implements BinaryContentFiles {
  ApplicationBinaryContentFiles(this.account);
  final String account;
  late final Future<DirectoryBinaryContentFilesImpl>
  _delegate = getApplicationSupportDirectory().then(
    (directory) => DirectoryBinaryContentFilesImpl(
      '${directory.path}/offline/${sha256.convert(utf8.encode(account))}/binary',
    ),
  );

  @override
  Future<BinaryContentReference> write(
    String collection,
    String item,
    String extension,
    Stream<List<int>> bytes,
  ) async => (await _delegate).write(collection, item, extension, bytes);

  @override
  Future<bool> verify(BinaryContentReference reference) async =>
      (await _delegate).verify(reference);

  @override
  Future<String> localPath(BinaryContentReference reference) async =>
      (await _delegate).localPath(reference);
}

class DirectoryBinaryContentFilesImpl implements DirectoryBinaryContentFiles {
  DirectoryBinaryContentFilesImpl(String rootPath)
    : _root = Directory(rootPath);

  final Directory _root;

  String _component(String value) =>
      value.length <= 80 && RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(value)
      ? value
      : 'id_${sha256.convert(utf8.encode(value))}';

  String _extension(String value) {
    final extension = value.toLowerCase();
    if (!RegExp(r'^\.[a-z0-9]{1,10}$').hasMatch(extension)) {
      throw const FormatException('Unsafe binary file extension');
    }
    return extension;
  }

  Future<File> _file(BinaryContentReference reference) async {
    if (!RegExp(
      r'^[A-Za-z0-9_-]+/[A-Za-z0-9_-]+/[a-f0-9]{64}\.[a-z0-9]{1,10}$',
    ).hasMatch(reference.path)) {
      throw const FormatException('Unsafe binary content path');
    }
    final path = File('${_root.path}/${reference.path}');
    final resolved = path.absolute.path;
    if (!resolved.startsWith('${_root.absolute.path}/')) {
      throw const FormatException('Binary content path escaped its account');
    }
    return path;
  }

  @override
  Future<BinaryContentReference> write(
    String collection,
    String item,
    String extension,
    Stream<List<int>> bytes,
  ) async {
    await _root.create(recursive: true);
    final staging = await _root.createTemp('.staging-');
    final temporary = File('${staging.path}/content');
    try {
      final sink = temporary.openWrite();
      var count = 0;
      await for (final chunk in bytes) {
        count += chunk.length;
        sink.add(chunk);
      }
      await sink.flush();
      await sink.close();
      if (count == 0) throw const FormatException('Binary content is empty');
      final hash = (await sha256.bind(temporary.openRead()).first).toString();
      final relative =
          '${_component(collection)}/${_component(item)}/$hash${_extension(extension)}';
      final reference = BinaryContentReference(
        path: relative,
        hash: hash,
        bytes: count,
      );
      final destination = await _file(reference);
      await destination.parent.create(recursive: true);
      if (await destination.exists()) {
        if (!await verify(reference)) {
          await destination.delete();
          await temporary.rename(destination.path);
        }
      } else {
        await temporary.rename(destination.path);
      }
      return reference;
    } finally {
      if (await temporary.exists()) await temporary.delete();
      await staging.delete(recursive: true);
    }
  }

  @override
  Future<bool> verify(BinaryContentReference reference) async {
    try {
      final file = await _file(reference);
      if (!await file.exists() || await file.length() != reference.bytes) {
        return false;
      }
      return (await sha256.bind(file.openRead()).first).toString() ==
          reference.hash;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String> localPath(BinaryContentReference reference) async {
    if (!await verify(reference)) {
      throw const FileSystemException('Binary content is missing or corrupt');
    }
    return (await _file(reference)).absolute.path;
  }
}
