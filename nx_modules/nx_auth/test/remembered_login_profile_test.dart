import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_auth/nx_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginHarness extends StatefulWidget {
  const LoginHarness({super.key});
  @override
  State<LoginHarness> createState() => _LoginHarnessState();
}

class _LoginHarnessState extends State<LoginHarness>
    with RememberedLoginProfile<LoginHarness> {
  @override
  Widget build(BuildContext context) => AuthLoginFields(
    preset: BackendPreset.hosted,
    profile: selectedLoginProfile,
    loading: restoringLoginProfile,
    onPresetChanged: (_) {},
    onProfileChanged: (profile) =>
        setState(() => selectedLoginProfile = profile),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ProviderContainer container() {
    final result = ProviderContainer(
      overrides: [
        authProvider.overrideWith(
          () => AuthController(initialDelay: Duration.zero),
        ),
        domainLoaderProvider.overrideWithValue((_) async => const []),
      ],
    );
    addTearDown(result.dispose);
    return result;
  }

  test('successful switch survives logout and a new app session', () async {
    SharedPreferences.setMockInitialValues({});
    final first = container();
    await first.read(authProvider.future);
    final controller = first.read(authProvider.notifier);
    expect(await controller.login('1', BackendPreset.localhost), isNull);
    expect(await controller.login('2', BackendPreset.localhost), isNull);
    final reopened = container();
    expect((await reopened.read(authProvider.future))?.userId, '2');
    await reopened.read(authProvider.notifier).logout();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(PrefsKeys.userId), isNull);
    expect(prefs.getString(PrefsKeys.lastUserId), '2');
    expect(await loadLastLoginProfile(), authLoginProfiles[1]);
    expect(await container().read(authProvider.future), isNull);
  });

  test('failed sign-in does not replace the last successful account', () async {
    SharedPreferences.setMockInitialValues({PrefsKeys.lastUserId: '2'});
    final app = container();
    await app.read(authProvider.future);
    expect(
      await app.read(authProvider.notifier).login('', BackendPreset.localhost),
      isNotNull,
    );
    expect((await loadLastLoginProfile())?.userId, '2');
  });

  test('expired legacy session retains its account for sign-in', () async {
    SharedPreferences.setMockInitialValues({
      PrefsKeys.userId: '2',
      PrefsKeys.backendPreset: BackendPreset.hosted.key,
    });
    final app = ProviderContainer(
      overrides: [
        authProvider.overrideWith(
          () => AuthController(initialDelay: Duration.zero),
        ),
        oidcSessionRestoreProvider.overrideWithValue((_, __) async => null),
      ],
    );
    addTearDown(app.dispose);
    expect(await app.read(authProvider.future), isNull);
    expect((await loadLastLoginProfile())?.userId, '2');
  });

  for (final id in [null, 'unknown', '2']) {
    testWidgets('account picker restores $id without choosing a default', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        if (id != null) PrefsKeys.lastUserId: id,
      });
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: LoginHarness())),
      );
      await tester.pumpAndSettle();
      final field = tester.state<FormFieldState<AuthLoginProfile>>(
        find.byType(DropdownButtonFormField<AuthLoginProfile>),
      );
      expect(field.value?.userId, id == '2' ? '2' : null);
      if (id != '2') expect(find.text('Select person'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<AuthLoginProfile>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nathik').last);
      await tester.pumpAndSettle();
      expect(
        (await SharedPreferences.getInstance()).getString(PrefsKeys.lastUserId),
        id,
      );
    });
  }
}
