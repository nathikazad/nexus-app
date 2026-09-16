import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_expense/app.dart';
import 'package:nx_expense/router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SignedIn extends AuthController {
  @override
  Future<User?> build() async =>
      User(userId: '1', preset: BackendPreset.localhost);
}

void main() {
  testWidgets('expenses wait for Home selection before mounting data screens', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    var mountedDataScreen = false;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) {
            mountedDataScreen = true;
            return const Scaffold(body: Text('Expense content'));
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(_SignedIn.new),
        routerProvider.overrideWithValue(router),
        domainLoaderProvider.overrideWithValue(
          (_) async => const [
            DomainMembership(id: 1, name: 'Personal', role: 'owner'),
            DomainMembership(id: 2, name: 'Home', role: 'member'),
          ],
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(authProvider.future);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const NexusExpenseApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Choose a domain'), findsOneWidget);
    expect(mountedDataScreen, isFalse);
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.text('Expense content'), findsOneWidget);
  });
}
