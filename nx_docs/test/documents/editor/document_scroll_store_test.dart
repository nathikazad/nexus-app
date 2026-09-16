import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nx_docs/documents/editor/document_scroll_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'positions persist locally and remain isolated across sessions and documents',
    () async {
      SharedPreferences.setMockInitialValues({});
      const store = DocumentScrollStore('server:1:user:1:domain:1');
      const anchor = <String, Object>{
        'documentId': 42,
        'blockIndex': 3,
        'blockKey': 'paragraph:x',
        'alignment': 0.5,
      };
      await store.write('Document', 42, anchor);
      expect(
        await const DocumentScrollStore(
          'server:1:user:1:domain:1',
        ).read('Document', 42),
        anchor,
      );
      for (final scope in [
        'server:2:user:1:domain:1',
        'server:1:user:2:domain:1',
        'server:1:user:1:domain:2',
      ]) {
        expect(await DocumentScrollStore(scope).read('Document', 42), isNull);
      }
      expect(await store.read('Document', 43), isNull);
      expect(await store.read('Book', 42), isNull);
    },
  );
  test('corrupt local positions are ignored', () async {
    const store = DocumentScrollStore('scope');
    SharedPreferences.setMockInitialValues({
      store.key('Document', 1): 'not json',
    });
    expect(await store.read('Document', 1), isNull);
  });
}
