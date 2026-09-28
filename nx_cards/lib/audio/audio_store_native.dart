import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart' as crypto;
import 'package:path_provider/path_provider.dart';
import 'audio_asset.dart';
import 'audio_store.dart';

class ApplicationAudioStore implements AudioStore {
  ApplicationAudioStore(String account)
    : _directory = getApplicationSupportDirectory().then(
        (dir) => DirectoryAudioStore(
          Directory(
            '${dir.path}/cards-audio/${crypto.sha256.convert(utf8.encode(account))}',
          ),
        ),
      );
  final Future<DirectoryAudioStore> _directory;
  @override
  Future<Uint8List?> read(AudioAsset asset) async =>
      (await _directory).read(asset);
  @override
  Future<void> write(AudioAsset asset, Uint8List bytes) async =>
      (await _directory).write(asset, bytes);
  @override
  Future<void> retain(Set<String> hashes) async =>
      (await _directory).retain(hashes);
}

class DirectoryAudioStore implements AudioStore {
  DirectoryAudioStore(this.directory);
  final Directory directory;
  File _file(AudioAsset asset) {
    asset.validate();
    return File('${directory.path}/${asset.sha256}.mp3');
  }

  static bool valid(AudioAsset asset, Uint8List bytes) =>
      bytes.isNotEmpty &&
      (asset.bytes == null || bytes.length == asset.bytes) &&
      crypto.sha256.convert(bytes).toString() == asset.sha256;
  @override
  Future<Uint8List?> read(AudioAsset asset) async {
    final file = _file(asset);
    if (!await file.exists()) return null;
    final bytes = await file.readAsBytes();
    return valid(asset, bytes) ? bytes : null;
  }

  @override
  Future<void> write(AudioAsset asset, Uint8List bytes) async {
    final file = _file(asset);
    if (!valid(asset, bytes)) {
      throw const FormatException('Audio checksum or size mismatch');
    }
    await directory.create(recursive: true);
    final staging = await directory.createTemp('.download-');
    try {
      final temporary = File('${staging.path}/audio');
      await temporary.writeAsBytes(bytes, flush: true);
      await temporary.rename(file.path);
    } finally {
      await staging.delete(recursive: true);
    }
  }

  @override
  Future<void> retain(Set<String> hashes) async {
    if (!await directory.exists()) return;
    await for (final entry in directory.list()) {
      final name = entry.uri.pathSegments.last;
      if (entry is File &&
          RegExp(r'^[a-f0-9]{64}\.mp3$').hasMatch(name) &&
          !hashes.contains(name.substring(0, 64))) {
        await entry.delete();
      }
    }
  }
}
