import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_notes/core/theme/app_theme.dart';
import 'package:nx_notes/features/settings/notes_settings_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('settings dialog changes theme and runs a hard refetch', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      AppDarkModeNotifier.preferenceKey: false,
    });
    var refetches = 0;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: _SettingsHarness(
              onHardRefetch: () async {
                refetches++;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('light'), findsOneWidget);
    await tester.tap(find.byKey(const Key('notes-settings-button')));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
    expect(find.text('Hard refetch'), findsOneWidget);

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(find.text('dark'), findsOneWidget);

    await tester.tap(find.byKey(const Key('hard-refetch-button')));
    await tester.pumpAndSettle();

    expect(refetches, 1);
    expect(find.text('Full library downloaded.'), findsOneWidget);
  });
}

class _SettingsHarness extends ConsumerWidget {
  const _SettingsHarness({required this.onHardRefetch});

  final HardRefetchCallback onHardRefetch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(appDarkModeProvider);
    return Column(
      children: <Widget>[
        Text(isDark ? 'dark' : 'light'),
        NotesSettingsButton(onHardRefetch: onHardRefetch),
      ],
    );
  }
}
