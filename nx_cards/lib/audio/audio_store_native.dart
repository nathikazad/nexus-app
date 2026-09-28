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
  Future<bool> contains(AudioAsset asset) async =>
      (await _directory).contains(asset);
  @override
  Future<void> flush() async => (await _directory).flush();
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
  late final Future<Map<String, dynamic>> _index = _loadIndex();
  Future<void> _saving = Future.value();
  int _revision = 0;
  int _savedRevision = 0;

  File get _indexFile => File('${directory.path}/verified.json');
  Future<Map<String, dynamic>> _loadIndex() async {
    try {
      return Map<String, dynamic>.from(
        jsonDecode(await _indexFile.readAsString()) as Map,
      );
    } on FileSystemException {
      return {};
    } on FormatException {
      return {};
    } on TypeError {
      return {};
    }
  }

  List<int> _stamp(FileStat stat) => [
    stat.size,
    stat.modified.microsecondsSinceEpoch,
    stat.changed.microsecondsSinceEpoch,
  ];

  @override
  Future<bool> contains(AudioAsset asset) async {
    final file = _file(asset);
    final stat = await file.stat();
    final index = await _index;
    if (stat.type != FileSystemEntityType.file ||
        stat.size == 0 ||
        (asset.bytes != null && stat.size != asset.bytes)) {
      if (index.remove(asset.sha256) != null) _revision++;
      return false;
    }
    final stamp = _stamp(stat);
    final previous = index[asset.sha256];
    if (previous is List &&
        previous.length == stamp.length &&
        List.generate(
          stamp.length,
          (i) => previous[i] == stamp[i],
        ).every((same) => same)) {
      return true;
    }
    // Existing files only need a full check once, or after their metadata changes.
    final digest = (await crypto.sha256.bind(file.openRead()).first).toString();
    if (digest != asset.sha256) {
      if (index.remove(asset.sha256) != null) _revision++;
      return false;
    }
    index[asset.sha256] = stamp;
    _revision++;
    return true;
  }

  @override
  Future<void> flush() {
    // Serialize atomic index writes when playback overlaps background sync.
    final next = _saving.catchError((Object _) {}).then((_) async {
      final index = await _index;
      if (_revision == _savedRevision) return;
      final revision = _revision;
      if (index.isEmpty && !await directory.exists()) return;
      await directory.create(recursive: true);
      final temporary = File('${directory.path}/.verified.tmp');
      await temporary.writeAsString(jsonEncode(index), flush: true);
      await temporary.rename(_indexFile.path);
      _savedRevision = revision;
    });
    _saving = next;
    return next;
  }

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
      (await _index)[asset.sha256] = _stamp(await file.stat());
      _revision++;
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
        (await _index).remove(name.substring(0, 64));
        _revision++;
      }
    }
  }
}
