import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:nx_docs/application/ports/document_asset_store.dart';
import 'package:nx_docs/domain/assets/document_asset.dart';

class MemoryDocumentAssetStore implements DocumentAssetStore {
  final Map<String, Uint8List> _bytes = <String, Uint8List>{};
  final Map<String, DocumentAsset> _assets = <String, DocumentAsset>{};

  @override
  Future<DocumentAsset> importBytes(Uint8List bytes) async {
    final hash = sha256.convert(bytes).toString();
    final uri = 'nxasset://$hash';
    _bytes.putIfAbsent(uri, () => Uint8List.fromList(bytes));
    return _assets.putIfAbsent(
      uri,
      () =>
          DocumentAsset(uri: uri, contentHash: hash, byteLength: bytes.length),
    );
  }

  @override
  Future<Uint8List?> read(String uri) async {
    final value = _bytes[uri];
    return value == null ? null : Uint8List.fromList(value);
  }

  @override
  Future<void> delete(String uri) async {
    _bytes.remove(uri);
    _assets.remove(uri);
  }

  @override
  Future<void> markUploaded(String uri, String remoteUrl) async {
    final asset = _assets[uri];
    if (asset == null) throw StateError('asset not found: $uri');
    _assets[uri] = asset.withRemoteUrl(remoteUrl);
  }

  @override
  Future<List<DocumentAsset>> pendingUploads() async => _assets.values
      .where((asset) => asset.pendingUpload)
      .toList(growable: false);
}
