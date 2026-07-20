import 'dart:typed_data';

import 'package:nx_notes/domain/assets/document_asset.dart';

abstract interface class DocumentAssetStore {
  Future<DocumentAsset> importBytes(Uint8List bytes);

  Future<Uint8List?> read(String uri);

  Future<void> delete(String uri);

  Future<void> markUploaded(String uri, String remoteUrl);

  Future<List<DocumentAsset>> pendingUploads();
}
