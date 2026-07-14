import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_people/data/auth/people_auth_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('restores the last saved user by default', () async {
    SharedPreferences.setMockInitialValues({
      PrefsKeys.userId: '2',
      PrefsKeys.backendPreset: BackendPreset.piWan.key,
    });
    final container = ProviderContainer(
      overrides: [authProvider.overrideWith(PeopleAuthController.new)],
    );
    addTearDown(container.dispose);

    final user = await container.read(authProvider.future);

    expect(user, isNotNull);
    expect(user!.userId, '2');
    expect(user.preset, BackendPreset.piWan);
  });

  test('uses explicit initial user when provided', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(
          () => PeopleAuthController(
            initialUser: User(userId: '2', preset: BackendPreset.defaultPreset),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final user = await container.read(authProvider.future);

    expect(user, isNotNull);
    expect(user!.userId, '2');
    expect(user.preset, BackendPreset.defaultPreset);
  });

  test('logout clears the saved user', () async {
    SharedPreferences.setMockInitialValues({
      PrefsKeys.userId: '2',
      PrefsKeys.backendPreset: BackendPreset.piWan.key,
    });
    final container = ProviderContainer(
      overrides: [authProvider.overrideWith(PeopleAuthController.new)],
    );
    addTearDown(container.dispose);

    expect(await container.read(authProvider.future), isNotNull);

    await container.read(authProvider.notifier).logout();
    final prefs = await SharedPreferences.getInstance();

    expect(container.read(authProvider).value, isNull);
    expect(prefs.getString(PrefsKeys.userId), isNull);
    expect(prefs.getString(PrefsKeys.backendPreset), isNull);
  });
}
