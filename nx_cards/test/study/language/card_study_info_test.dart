import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/study/language/card_study_info.dart';

void main() {
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
