import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:nx_docs/documents/assets/document_asset_store.dart';
import 'package:nx_docs/documents/assets/document_asset.dart';

class FilesystemDocumentAssetStore implements DocumentAssetStore {
  const FilesystemDocumentAssetStore(this.directory);

  final Directory directory;

  @override
  Future<DocumentAsset> importBytes(Uint8List bytes) async {
    await directory.create(recursive: true);
    final hash = sha256.convert(bytes).toString();
    final destination = _assetFile(hash);
    if (!await destination.exists()) {
      final temporary = File(
        '${destination.path}.tmp-${DateTime.now().microsecondsSinceEpoch}',
      );
      try {
        await temporary.writeAsBytes(bytes, flush: true);
        await temporary.rename(destination.path);
      } finally {
        if (await temporary.exists()) await temporary.delete();
      }
    }
    return _describe(hash);
  }

  @override
  Future<Uint8List?> read(String uri) async {
    final hash = _hashFromUri(uri);
    if (hash == null) return null;
    final file = _assetFile(hash);
    return await file.exists() ? file.readAsBytes() : null;
  }

  @override
  Future<void> delete(String uri) async {
    final hash = _hashFromUri(uri);
    if (hash == null) return;
    final asset = _assetFile(hash);
    final remote = _remoteFile(hash);
    if (await asset.exists()) await asset.delete();
    if (await remote.exists()) await remote.delete();
  }

  @override
  Future<void> markUploaded(String uri, String remoteUrl) async {
    final hash = _hashFromUri(uri);
    if (hash == null || !await _assetFile(hash).exists()) {
      throw StateError('asset not found: $uri');
    }
    await _remoteFile(hash).writeAsString(remoteUrl, flush: true);
  }

  @override
  Future<List<DocumentAsset>> pendingUploads() async {
    if (!await directory.exists()) return const <DocumentAsset>[];
    final assets = <DocumentAsset>[];
    await for (final entity in directory.list()) {
      if (entity is! File || !entity.path.endsWith('.asset')) continue;
      final hash = entity.uri.pathSegments.last.replaceFirst('.asset', '');
      final asset = await _describe(hash);
      if (asset.pendingUpload) assets.add(asset);
    }
    return assets;
  }

  Future<DocumentAsset> _describe(String hash) async {
    final file = _assetFile(hash);
    final remote = _remoteFile(hash);
    return DocumentAsset(
      uri: 'nxasset://$hash',
      contentHash: hash,
      byteLength: await file.length(),
      remoteUrl: await remote.exists()
          ? utf8.decode(await remote.readAsBytes())
          : null,
    );
  }

  File _assetFile(String hash) => File('${directory.path}/$hash.asset');
  File _remoteFile(String hash) => File('${directory.path}/$hash.remote');

  String? _hashFromUri(String uri) {
    const prefix = 'nxasset://';
    if (!uri.startsWith(prefix)) return null;
    final hash = uri.substring(prefix.length);
    return RegExp(r'^[a-f0-9]{64}$').hasMatch(hash) ? hash : null;
  }
}
