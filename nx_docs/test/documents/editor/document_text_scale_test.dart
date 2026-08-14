import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_docs/documents/editor/document_text_scale.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('command plus and minus change and persist document text scale', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: DocumentTextScaleShortcuts(child: _ScaleHarness()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('focus-target')));

    expect(find.text('1.0'), findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.equal);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();

    expect(find.text('1.1'), findsOneWidget);
    var preferences = await SharedPreferences.getInstance();
    expect(preferences.getDouble(DocumentTextScaleNotifier.preferenceKey), 1.1);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.minus);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();

    expect(find.text('1.0'), findsOneWidget);
    preferences = await SharedPreferences.getInstance();
    expect(preferences.getDouble(DocumentTextScaleNotifier.preferenceKey), 1.0);
  });

  testWidgets('saved document text scale is restored', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      DocumentTextScaleNotifier.preferenceKey: 1.4,
    });

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: _ScaleHarness())),
    );
    await tester.pumpAndSettle();

    expect(find.text('1.4'), findsOneWidget);
  });
}

class _ScaleHarness extends ConsumerWidget {
  const _ScaleHarness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = ref.watch(documentTextScaleProvider);
    return Scaffold(
      body: Column(
        children: <Widget>[
          Text(scale.toStringAsFixed(1)),
          const TextButton(
            key: Key('focus-target'),
            onPressed: _noop,
            child: Text('Focus'),
          ),
        ],
      ),
    );
  }
}

void _noop() {}
