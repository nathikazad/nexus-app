import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/study/language/card_study_info.dart';

void main() {
  testWidgets('reveal shows controls without moving the writing layout', (
    tester,
  ) async {
    var opened = false;
    Widget page(bool visible) => MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            CardStudyInfo(
              spokenOnly: true,
              visible: visible,
              onOpen: () => opened = true,
            ),
            const SizedBox(key: ValueKey('writing'), width: 240, height: 200),
          ],
        ),
      ),
    );
    await tester.pumpWidget(page(false));
    final before = tester.getRect(find.byKey(const ValueKey('writing')));
    expect(find.byTooltip('Card details').hitTestable(), findsNothing);
    expect(find.text('Audio only').hitTestable(), findsNothing);
    await tester.pumpWidget(page(true));
    expect(tester.getRect(find.byKey(const ValueKey('writing'))), before);
    expect(find.text('Audio only').hitTestable(), findsOneWidget);
    await tester.tap(find.byTooltip('Card details'));
    expect(opened, isTrue);
  });

  for (final spoken in [false, true]) {
    testWidgets('details is available with audio-only=$spoken', (tester) async {
      var opened = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 240,
              child: CardStudyInfo(
                spokenOnly: spoken,
                onOpen: () => opened = true,
              ),
            ),
          ),
        ),
      );
      expect(find.text('Audio only'), spoken ? findsOneWidget : findsNothing);
      if (spoken) {
        expect(
          tester.getRect(find.text('Audio only')).right,
          lessThan(tester.getRect(find.byTooltip('Card details')).left),
        );
      }
      await tester.tap(find.byTooltip('Card details'));
      expect(opened, isTrue);
      expect(tester.takeException(), isNull);
    });
  }
}
