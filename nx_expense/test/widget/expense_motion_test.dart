import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nx_expense/core/motion/expense_motion.dart';

void main() {
  for (final reduced in [false, true]) {
    testWidgets(
      'navigation completes and reverses with reduced motion $reduced',
      (tester) async {
        Page<void>? detailPage;
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => Scaffold(
                body: TextButton(
                  onPressed: () => context.push('/orders/1'),
                  child: const Text('Open'),
                ),
              ),
            ),
            GoRoute(
              path: '/orders/:id',
              pageBuilder: (context, state) {
                detailPage = ExpenseMotion.page(
                  context,
                  state,
                  Scaffold(
                    body: TextButton(
                      onPressed: () => context.pop(),
                      child: const Text('Back to list'),
                    ),
                  ),
                );
                return detailPage!;
              },
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          MaterialApp.router(
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
              child: child!,
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pump();
        expect(
          detailPage,
          reduced
              ? isA<NoTransitionPage<void>>()
              : isA<CustomTransitionPage<void>>(),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Back to list'));
        await tester.pumpAndSettle();
        expect(find.text('Open'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('compact iOS retains native interactive route', (tester) async {
    Page<void>? page;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          pageBuilder: (context, state) {
            page = ExpenseMotion.page(
              context,
              state,
              const Scaffold(body: Text('Order')),
            );
            return page!;
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        theme: ThemeData(platform: TargetPlatform.iOS),
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();
    expect(page, isA<CupertinoPage<void>>());
  });
}
