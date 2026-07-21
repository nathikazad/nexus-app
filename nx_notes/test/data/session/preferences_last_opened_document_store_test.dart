import 'package:flutter_test/flutter_test.dart';
import 'package:nx_notes/data/session/preferences_last_opened_document_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'last-opened document persists independently for each account',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final store = PreferencesLastOpenedDocumentStore(
        await SharedPreferences.getInstance(),
      );

      await store.save('production:user-1', 41);
      await store.save('production:user-2', 99);

      expect(await store.load('production:user-1'), 41);
      expect(await store.load('production:user-2'), 99);
    },
  );

  test('invalid ids are ignored and one account can be cleared', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = PreferencesLastOpenedDocumentStore(
      await SharedPreferences.getInstance(),
    );

    await store.save('production:user-1', 41);
    await store.save('production:user-2', 99);
    await store.save('production:user-1', 0);
    await store.clear('production:user-1');

    expect(await store.load('production:user-1'), isNull);
    expect(await store.load('production:user-2'), 99);
  });
}
