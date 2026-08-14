import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_docs/app/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('explicit theme choice persists across provider restarts', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      AppDarkModeNotifier.preferenceKey: false,
    });

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: _ThemeHarness())),
    );
    await tester.pumpAndSettle();

    expect(find.text('light'), findsOneWidget);

    await tester.tap(find.text('toggle'));
    await tester.pumpAndSettle();

    expect(find.text('dark'), findsOneWidget);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool(AppDarkModeNotifier.preferenceKey), isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: _ThemeHarness())),
    );
    await tester.pumpAndSettle();

    expect(find.text('dark'), findsOneWidget);
  });
}

class _ThemeHarness extends ConsumerWidget {
  const _ThemeHarness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(appDarkModeProvider);
    return Scaffold(
      body: Column(
        children: <Widget>[
          Text(isDark ? 'dark' : 'light'),
          TextButton(
            onPressed: () => ref.read(appDarkModeProvider.notifier).toggle(),
            child: const Text('toggle'),
          ),
        ],
      ),
    );
  }
}
