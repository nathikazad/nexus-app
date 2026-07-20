import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nx_notes/application/ports/document_asset_store.dart';

typedef AssetStoreFactory = Future<DocumentAssetStore> Function();

void runDocumentAssetStoreContract({required AssetStoreFactory createStore}) {
  late DocumentAssetStore store;

  setUp(() async => store = await createStore());

  test('imports and reads bytes through a stable local uri', () async {
    final bytes = Uint8List.fromList(<int>[1, 2, 3, 4]);
    final asset = await store.importBytes(bytes);

    expect(asset.uri, startsWith('nxasset://'));
    expect(await store.read(asset.uri), bytes);
  });

  test('deduplicates identical content', () async {
    final bytes = Uint8List.fromList(<int>[4, 3, 2, 1]);
    final first = await store.importBytes(bytes);
    final second = await store.importBytes(bytes);

    expect(second.uri, first.uri);
    expect(await store.pendingUploads(), hasLength(1));
  });

  test(
    'uploaded assets leave the pending queue without losing bytes',
    () async {
      final asset = await store.importBytes(Uint8List.fromList(<int>[8, 9]));
      await store.markUploaded(asset.uri, 'https://example.test/asset');

      expect(await store.pendingUploads(), isEmpty);
      expect(await store.read(asset.uri), <int>[8, 9]);
    },
  );

  test('delete removes local content', () async {
    final asset = await store.importBytes(Uint8List.fromList(<int>[7]));
    await store.delete(asset.uri);

    expect(await store.read(asset.uri), isNull);
  });
}
