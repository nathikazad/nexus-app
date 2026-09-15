import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_auth/nx_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SignedIn extends AuthController {
  @override
  Future<User?> build() async =>
      User(userId: '7', preset: BackendPreset.localhost);
}

void main() {
  testWidgets(
    'picker gates content and switching returns to domain selection',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(_SignedIn.new),
            domainLoaderProvider.overrideWithValue(
              (_) async => const [
                DomainMembership(id: 1, name: 'Personal', role: 'owner'),
                DomainMembership(id: 2, name: 'Home', role: 'member'),
              ],
            ),
          ],
          child: MaterialApp(
            home: DomainSessionGate(
              child: Scaffold(
                body: Builder(
                  builder: (context) => Column(
                    children: [
                      const Text('Domain content'),
                      TextButton(
                        onPressed: () => showDialog<void>(
                          context: context,
                          builder: (_) => const AlertDialog(
                            content: SizedBox(
                              width: 360,
                              child: DomainSettingsTile(),
                            ),
                          ),
                        ),
                        child: const Text('Settings'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Choose a domain'), findsOneWidget);
      expect(find.text('Domain content'), findsNothing);
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      expect(find.text('Domain content'), findsOneWidget);
      expect(find.text('Home ▾'), findsNothing);
      expect(find.text('Domain'), findsNothing);
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
      await tester.tap(find.text('Switch'));
      await tester.pumpAndSettle();
      expect(find.text('Choose a domain'), findsOneWidget);
      expect(find.text('Domain content'), findsNothing);
    },
  );
}
