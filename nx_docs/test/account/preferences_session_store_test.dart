import 'package:flutter_test/flutter_test.dart';
import 'package:nx_docs/account/account_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'session round-trips and clears without touching other preferences',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{'other': 'kept'});
      final preferences = await SharedPreferences.getInstance();
      final store = PreferencesSessionStore(preferences);
      const session = CachedSession(
        userId: 'user-1',
        backendPreset: 'production',
      );

      await store.save(session);
      final restored = await store.load();
      expect(restored!.accountKey, session.accountKey);

      await store.clear();
      expect(await store.load(), isNull);
      expect(preferences.getString('other'), 'kept');
    },
  );

  test('partial credentials do not restore', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      PreferencesSessionStore.userIdKey: 'user-1',
    });
    final store = PreferencesSessionStore(
      await SharedPreferences.getInstance(),
    );

    expect(await store.load(), isNull);
  });
}
