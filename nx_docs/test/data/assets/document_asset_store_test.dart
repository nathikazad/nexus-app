import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nx_docs/data/assets/filesystem_document_asset_store.dart';
import 'package:nx_docs/data/assets/memory_document_asset_store.dart';

import '../../support/contracts/document_asset_store_contract.dart';

void main() {
  group('MemoryDocumentAssetStore contract', () {
    runDocumentAssetStoreContract(
      createStore: () async => MemoryDocumentAssetStore(),
    );
  });

  group('FilesystemDocumentAssetStore contract', () {
    late Directory directory;
    setUp(() async {
      directory = await Directory.systemTemp.createTemp('nx_docs_assets_');
    });
    tearDown(() async {
      if (directory.existsSync()) await directory.delete(recursive: true);
    });
    runDocumentAssetStoreContract(
      createStore: () async => FilesystemDocumentAssetStore(directory),
    );
  });

  test('filesystem references survive adapter restart', () async {
    final directory = await Directory.systemTemp.createTemp(
      'nx_docs_asset_restart_',
    );
    addTearDown(() => directory.delete(recursive: true));
    var store = FilesystemDocumentAssetStore(directory);
    final asset = await store.importBytes(Uint8List.fromList(<int>[1, 3, 5]));

    store = FilesystemDocumentAssetStore(directory);

    expect(await store.read(asset.uri), <int>[1, 3, 5]);
    expect((await store.pendingUploads()).single.uri, asset.uri);
  });

  test('incomplete temporary files are never visible', () async {
    final directory = await Directory.systemTemp.createTemp(
      'nx_docs_asset_crash_',
    );
    addTearDown(() => directory.delete(recursive: true));
    await File('${directory.path}/broken.asset.tmp-1').writeAsBytes(<int>[1]);
    final store = FilesystemDocumentAssetStore(directory);

    expect(await store.pendingUploads(), isEmpty);
  });
}
